# This file constructs the standard build environment for the
# Linux platform.  It's completely pure; that is, it relies on no
# external (non-Nix) tools, such as /usr/bin/gcc, and it contains a C
# compiler and linker that do not search in default locations,
# ensuring purity of components produced by it.
#
# It starts from prebuilt seed bootstrapFiles and creates a series of
# nixpkgs instances (stages) to gradually rebuild stdenv, which
# is used to build all other packages (including the bootstrapFiles).
#
# Goals of the bootstrap process:
# 1. final stdenv must not reference any of the bootstrap files.
# 2. final stdenv must not contain any of the bootstrap files.
# 3. final stdenv must not contain any of the files directly
#    generated by the bootstrap code generators (assembler, linker,
#    compiler).
#
# These goals ensure that final packages and final stdenv are built
# exclusively using nixpkgs package definitions and don't depend
# on bootstrapTools (via direct references, inclusion
# of copied code, or code compiled directly by bootstrapTools).
#
# Stages are described below along with their definitions.
#
# Debugging stdenv dependency graph:
# An useful tool to explore dependencies across stages is to use
# '__bootPackages' attribute of 'stdenv. Examples of last 3 stages:
# - stdenv
# - stdenv.__bootPackages.stdenv
# - stdenv.__bootPackages.stdenv.__bootPackages.stdenv
# - ... and so on.
#
# To explore build-time dependencies in graphical form one can use
# the following:
#     $ nix-store --query --graph $(nix-instantiate -A stdenv) |
#         grep -P -v '[.]sh|[.]patch|bash|[.]tar' | # avoid clutter
#         dot -Tsvg > stdenv-final.svg
#
# To find all the packages built by a particular stdenv instance:
#    $ for stage in 0 1 2 3 4; do
#      echo "stage${stage} used in:"
#      nix-store --query --graph $(nix-instantiate -A stdenv) |
#          grep -P ".*bootstrap-stage${stage}-stdenv.*->.*" |
#          sed 's/"[0-9a-z]\{32\}-/"/g'
#      done
#
# To verify which stdenv was used to build a given final package:
#     $ nix-store --query --graph $(nix-instantiate -A stdenv) |
#       grep -P -v '[.]sh|[.]patch|bash|[.]tar' |
#       grep -P '.*stdenv.*->.*glibc-2'
#     "...-bootstrap-stage2-stdenv-linux.drv" -> "...-glibc-2.35-224.drv";
#
# For a TUI (rather than CLI) view, you can use:
#
#     $ nix-tree --derivation $(nix-instantiate -A stdenv)
{ lib
, localSystem, crossSystem, config, overlays, crossOverlays ? []

, bootstrapFiles ?
  let table = {
    glibc = {
      i686-linux = import ./bootstrap-files/i686-unknown-linux-gnu.nix;
      x86_64-linux = import ./bootstrap-files/x86_64-unknown-linux-gnu.nix;
      armv5tel-linux = import ./bootstrap-files/armv5tel-unknown-linux-gnueabi.nix;
      armv6l-linux = import ./bootstrap-files/armv6l-unknown-linux-gnueabihf.nix;
      armv7l-linux = import ./bootstrap-files/armv7l-unknown-linux-gnueabihf.nix;
      aarch64-linux = import ./bootstrap-files/aarch64-unknown-linux-gnu.nix;
      mipsel-linux = import ./bootstrap-files/mipsel-unknown-linux-gnu.nix;
      mips64el-linux = import
       (if localSystem.isMips64n32
        then ./bootstrap-files/mips64el-unknown-linux-gnuabin32.nix
        else ./bootstrap-files/mips64el-unknown-linux-gnuabi64.nix);
      powerpc64-linux = import ./bootstrap-files/powerpc64-unknown-linux-gnuabielfv2.nix;
      powerpc64le-linux = import ./bootstrap-files/powerpc64le-unknown-linux-gnu.nix;
      riscv64-linux = import ./bootstrap-files/riscv64-unknown-linux-gnu.nix;
      s390x-linux = import ./bootstrap-files/s390x-unknown-linux-gnu.nix;
    };
    musl = {
      aarch64-linux = import ./bootstrap-files/aarch64-unknown-linux-musl.nix;
      armv6l-linux  = import ./bootstrap-files/armv6l-unknown-linux-musleabihf.nix;
      x86_64-linux  = import ./bootstrap-files/x86_64-unknown-linux-musl.nix;
    };
  };

  # Try to find an architecture compatible with our current system. We
  # just try every bootstrap we’ve got and test to see if it is
  # compatible with or current architecture.
  getCompatibleTools = lib.foldl (v: system:
    if v != null then v
    else if localSystem.canExecute (lib.systems.elaborate { inherit system; }) then archLookupTable.${system}
    else null) null (lib.attrNames archLookupTable);

  archLookupTable = table.${localSystem.libc}
    or (throw "unsupported libc for the pure Linux stdenv");
  files = archLookupTable.${localSystem.system} or (if getCompatibleTools != null then getCompatibleTools
    else (throw "unsupported platform for the pure Linux stdenv"));
  in (config.replaceBootstrapFiles or lib.id) files
}:

assert crossSystem == localSystem;

let
  inherit (localSystem) system;

  isFromNixpkgs = pkg: !(isFromBootstrapFiles pkg);
  isFromBootstrapFiles =
    pkg: pkg.passthru.isFromBootstrapFiles or false;
  isBuiltByNixpkgsCompiler =
    pkg: isFromNixpkgs pkg && isFromNixpkgs pkg.stdenv.cc.cc;
  isBuiltByBootstrapFilesCompiler =
    pkg: isFromNixpkgs pkg && isFromBootstrapFiles pkg.stdenv.cc.cc;

  commonGccOverrides = {
    # Use a deterministically built compiler
    # see https://github.com/NixOS/nixpkgs/issues/108475 for context
    reproducibleBuild = true;
    profiledCompiler = false;

    # It appears that libcc1 (which is not a g++ plugin; it is a gdb plugin) gets linked against
    # the libstdc++ from the compiler that *built* g++, not the libstdc++ which was just built.
    # This causes a reference chain from stdenv to the bootstrapFiles:
    #
    #   stdenv -> gcc-lib -> xgcc-lib -> bootstrapFiles
    #
    disableGdbPlugin = true;
  };

  commonPreHook =
    ''
      export NIX_ENFORCE_PURITY="''${NIX_ENFORCE_PURITY-1}"
      export NIX_ENFORCE_NO_NATIVE="''${NIX_ENFORCE_NO_NATIVE-1}"
    '';


  # The bootstrap process proceeds in several steps.


  # Create a standard environment by downloading pre-built binaries of
  # coreutils, GCC, etc.


  # Download and unpack the bootstrap tools (coreutils, GCC, Glibc, ...).
  bootstrapTools = import ./bootstrap-tools {
    inherit (localSystem) libc system;
    inherit lib bootstrapFiles config;
    isFromBootstrapFiles = true;
  };

  getLibc = stage: stage.${localSystem.libc};


  # This function builds the various standard environments used during
  # the bootstrap.  In all stages, we build an stdenv and the package
  # set that can be built with that stdenv.
  stageFun = prevStage:
    { name, overrides ? (self: super: {}), extraNativeBuildInputs ? [] }:

    let

      thisStdenv = import ../generic {
        name = "${name}-stdenv-linux";
        buildPlatform = localSystem;
        hostPlatform = localSystem;
        targetPlatform = localSystem;
        inherit config extraNativeBuildInputs;
        preHook =
          ''
            # Don't patch #!/interpreter because it leads to retained
            # dependencies on the bootstrapTools in the final stdenv.
            dontPatchShebangs=1
            ${commonPreHook}
          '';
        shell = "${bootstrapTools}/bin/bash";
        initialPath = [bootstrapTools];

        fetchurlBoot = import ../../build-support/fetchurl/boot.nix {
          inherit system;
        };

        cc = if prevStage.gcc-unwrapped == null
             then null
             else (lib.makeOverridable (import ../../build-support/cc-wrapper) {
          name = "${name}-gcc-wrapper";
          nativeTools = false;
          nativeLibc = false;
          expand-response-params = lib.optionalString
            (prevStage.stdenv.hasCC or false && prevStage.stdenv.cc != "/dev/null")
            prevStage.expand-response-params;
          cc = prevStage.gcc-unwrapped;
          bintools = prevStage.binutils;
          isGNU = true;
          libc = getLibc prevStage;
          inherit lib;
          inherit (prevStage) coreutils gnugrep;
          stdenvNoCC = prevStage.ccWrapperStdenv;
          fortify-headers = prevStage.fortify-headers;
          runtimeShell = prevStage.ccWrapperStdenv.shell;
        }).overrideAttrs(a: lib.optionalAttrs (prevStage.gcc-unwrapped.passthru.isXgcc or false) {
          # This affects only `xgcc` (the compiler which compiles the final compiler).
          postFixup = (a.postFixup or "") + ''
            echo "--sysroot=${lib.getDev (getLibc prevStage)}" >> $out/nix-support/cc-cflags
          '';
        });

        overrides = self: super: (overrides self super) // { fetchurl = thisStdenv.fetchurlBoot; };
      };

    in {
      inherit config overlays;
      stdenv = thisStdenv;
    };

in
  assert bootstrapTools.passthru.isFromBootstrapFiles or false;  # sanity check
[

  ({}: {
    __raw = true;

    gcc-unwrapped = null;
    binutils = null;
    coreutils = null;
    gnugrep = null;
  })

  # Build a dummy stdenv with no GCC or working fetchurl.  This is
  # because we need a stdenv to build the GCC wrapper and fetchurl.
  (prevStage: stageFun prevStage {
    name = "bootstrap-stage0";

    overrides = self: super: {
      # We thread stage0's stdenv through under this name so downstream stages
      # can use it for wrapping gcc too. This way, downstream stages don't need
      # to refer to this stage directly, which violates the principle that each
      # stage should only access the stage that came before it.
      ccWrapperStdenv = self.stdenv;
      # The Glibc include directory cannot have the same prefix as the
      # GCC include directory, since GCC gets confused otherwise (it
      # will search the Glibc headers before the GCC headers).  So
      # create a dummy Glibc here, which will be used in the stdenv of
      # stage1.
      ${localSystem.libc} = self.stdenv.mkDerivation {
        pname = "bootstrap-stage0-${localSystem.libc}";
        strictDeps = true;
        version = "bootstrapFiles";
        enableParallelBuilding = true;
        buildCommand = ''
          mkdir -p $out
          ln -s ${bootstrapTools}/lib $out/lib
        '' + lib.optionalString (localSystem.libc == "glibc") ''
          ln -s ${bootstrapTools}/include-glibc $out/include
        '' + lib.optionalString (localSystem.libc == "musl") ''
          ln -s ${bootstrapTools}/include-libc $out/include
        '';
        passthru.isFromBootstrapFiles = true;
      };
      gcc-unwrapped = bootstrapTools;
      binutils = import ../../build-support/bintools-wrapper {
        name = "bootstrap-stage0-binutils-wrapper";
        nativeTools = false;
        nativeLibc = false;
        expand-response-params = "";
        libc = getLibc self;
        inherit lib;
        inherit (self) stdenvNoCC coreutils gnugrep;
        bintools = bootstrapTools;
        runtimeShell = "${bootstrapTools}/bin/bash";
      };
      coreutils = bootstrapTools;
      gnugrep = bootstrapTools;
    };
  })


  # Create the first "real" standard environment.  This one consists
  # of bootstrap tools only, and a minimal Glibc to keep the GCC
  # configure script happy.
  #
  # For clarity, we only use the previous stage when specifying these
  # stages.  So stageN should only ever have references for stage{N-1}.
  #
  # If we ever need to use a package from more than one stage back, we
  # simply re-export those packages in the middle stage(s) using the
  # overrides attribute and the inherit syntax.
  (prevStage:
    # previous stage0 stdenv:
    assert isFromBootstrapFiles prevStage.binutils.bintools;
    assert isFromBootstrapFiles prevStage."${localSystem.libc}";
    assert isFromBootstrapFiles prevStage.gcc-unwrapped;
    assert isFromBootstrapFiles prevStage.coreutils;
    assert isFromBootstrapFiles prevStage.gnugrep;
    stageFun prevStage {
    name = "bootstrap-stage1";

    # Rebuild binutils to use from stage2 onwards.
    overrides = self: super: {
      binutils-unwrapped = super.binutils-unwrapped.override {
        enableGold = false;
      };
      inherit (prevStage)
        ccWrapperStdenv
        gcc-unwrapped coreutils gnugrep binutils;

      ${localSystem.libc} = getLibc prevStage;

      # A threaded perl build needs glibc/libpthread_nonshared.a,
      # which is not included in bootstrapTools, so disable threading.
      # This is not an issue for the final stdenv, because this perl
      # won't be included in the final stdenv and won't be exported to
      # top-level pkgs as an override either.
      perl = super.perl.override { enableThreading = false; enableCrypt = false; };
    };

    # `gettext` comes with obsolete config.sub/config.guess that don't recognize LoongArch64.
    extraNativeBuildInputs = [ prevStage.updateAutotoolsGnuConfigScriptsHook ];
  })

  # First rebuild of gcc; this is linked against all sorts of junk
  # from the bootstrap-files, but we only care about the code that
  # this compiler *emits*.  The `gcc` binary produced in this stage
  # is not part of the final stdenv.
  (prevStage:
    assert isBuiltByBootstrapFilesCompiler prevStage.binutils-unwrapped;
    assert            isFromBootstrapFiles prevStage."${localSystem.libc}";
    assert            isFromBootstrapFiles prevStage.gcc-unwrapped;
    assert            isFromBootstrapFiles prevStage.coreutils;
    assert            isFromBootstrapFiles prevStage.gnugrep;
    assert isBuiltByBootstrapFilesCompiler prevStage.patchelf;
    stageFun prevStage {
      name = "bootstrap-stage-xgcc";
      overrides = self: super: {
        inherit (prevStage) ccWrapperStdenv coreutils gnugrep gettext bison texinfo zlib gnum4 perl patchelf;
        ${localSystem.libc} = getLibc prevStage;
        gmp = super.gmp.override { cxx = false; };
        # This stage also rebuilds binutils which will of course be used only in the next stage.
        # We inherit this until stage3, in stage4 it will be rebuilt using the adjacent bash/runtimeShell pkg.
        # TODO(@sternenseemann): Can we already build the wrapper with the actual runtimeShell here?
        # Historically, the wrapper didn't use runtimeShell, so the used shell had to be changed explicitly
        # (or stdenvNoCC.shell would be used) which happened in stage4.
        binutils = super.binutils.override {
          runtimeShell = "${bootstrapTools}/bin/bash";
        };
        gcc-unwrapped =
          (super.gcc-unwrapped.override (commonGccOverrides // {
            # The most logical name for this package would be something like
            # "gcc-stage1".  Unfortunately "stage" is already reserved for the
            # layers of stdenv, so using "stage" in the name of this package
            # would cause massive confusion.
            #
            # Gcc calls its "stage1" compiler `xgcc` (--disable-bootstrap results
            # in `xgcc` being copied to $prefix/bin/gcc).  So we imitate that.
            #
            name = "xgcc";

            # xgcc uses ld linked against nixpkgs' glibc and gcc built
            # against bootstrapTools glibc. We can't allow loading
            #   $out/libexec/gcc/x86_64-unknown-linux-gnu/13.0.1/liblto_plugin.so
            # to mix libc.so:
            #   ...-binutils-patchelfed-ld-2.40/bin/ld: ...-xgcc-13.0.0/libexec/gcc/x86_64-unknown-linux-gnu/13.0.1/liblto_plugin.so:
            #     error loading plugin: ...-bootstrap-tools/lib/libpthread.so.0: undefined symbol: __libc_vfork, version GLIBC_PRIVATE
            enableLTO = false;
          })).overrideAttrs (a: {

            # This signals to cc-wrapper (as overridden above in this file) to add `--sysroot`
            # to `$out/nix-support/cc-cflags`.
            passthru = a.passthru // { isXgcc = true; };

            # Gcc will look for the C library headers in
            #
            #    ${with_build_sysroot}${native_system_header_dir}
            #
            # The ordinary gcc expression sets `--with-build-sysroot=/` and sets
            # `native-system-header-dir` to `"${lib.getDev stdenv.cc.libc}/include`.
            #
            # Unfortunately the value of "--with-native-system-header-dir=" gets "burned in" to the
            # compiler, and it is quite difficult to get the compiler to change or ignore it
            # afterwards.  On the other hand, the `sysroot` is very easy to change; you can just pass
            # a `--sysroot` flag to `gcc`.
            #
            # So we override the expression to remove the default settings for these flags, and
            # replace them such that the concatenated value will be the same as before, but we split
            # the value between the two variables differently: `--native-system-header-dir=/include`,
            # and `--with-build-sysroot=${lib.getDev stdenv.cc.libc}`.
            #
            configureFlags = (a.configureFlags or []) ++ [
              "--with-native-system-header-dir=/include"
              "--with-build-sysroot=${lib.getDev self.stdenv.cc.libc}"
            ];

            # This is a separate phase because gcc assembles its phase scripts
            # in bash instead of nix (we should fix that).
            preFixupPhases = (a.preFixupPhases or []) ++ [ "preFixupXgccPhase" ];

            # This is needed to prevent "error: cycle detected in build of '...-xgcc-....drv'
            # in the references of output 'lib' from output 'out'"
            preFixupXgccPhase = ''
              find $lib/lib/ -name \*.so\* -exec patchelf --shrink-rpath {} \; || true
            '';
          });
      };

      # `gettext` comes with obsolete config.sub/config.guess that don't recognize LoongArch64.
      extraNativeBuildInputs = [ prevStage.updateAutotoolsGnuConfigScriptsHook ];
    })

  # 2nd stdenv that contains our own rebuilt binutils and is used for
  # compiling our own Glibc.
  #
  (prevStage:
    # previous stage1 stdenv:
    assert isBuiltByBootstrapFilesCompiler prevStage.binutils-unwrapped;
    assert            isFromBootstrapFiles prevStage."${localSystem.libc}";
    assert isBuiltByBootstrapFilesCompiler prevStage.gcc-unwrapped;
    assert            isFromBootstrapFiles prevStage.coreutils;
    assert            isFromBootstrapFiles prevStage.gnugrep;
    assert isBuiltByBootstrapFilesCompiler prevStage.patchelf;
    stageFun prevStage {
    name = "bootstrap-stage2";

    overrides = self: super: {
      inherit (prevStage)
        ccWrapperStdenv gettext
        gcc-unwrapped coreutils gnugrep
        perl gnum4 bison texinfo which;
      dejagnu = super.dejagnu.overrideAttrs (a: { doCheck = false; } );

      # We need libidn2 and its dependency libunistring as glibc dependency.
      # To avoid the cycle, we build against bootstrap libc, nuke references,
      # and use the result as input for our final glibc.  We also pass this pair
      # through, so the final package-set uses exactly the same builds.
      libunistring = super.libunistring.overrideAttrs (attrs: {
        postFixup = attrs.postFixup or "" + ''
          ${self.nukeReferences}/bin/nuke-refs "$out"/lib/lib*.so.*.*
        '';
        # Apparently iconv won't work with bootstrap glibc, but it will be used
        # with glibc built later where we keep *this* build of libunistring,
        # so we need to trick it into supporting libiconv.
        env = attrs.env or {} // { am_cv_func_iconv_works = "yes"; };
      });
      libidn2 = super.libidn2.overrideAttrs (attrs: {
        postFixup = attrs.postFixup or "" + ''
          ${self.nukeReferences}/bin/nuke-refs -e '${lib.getLib self.libunistring}' \
            "$out"/lib/lib*.so.*.*
        '';
      });

      # This also contains the full, dynamically linked, final Glibc.
      binutils = prevStage.binutils.override {
        # Rewrap the binutils with the new glibc, so both the next
        # stage's wrappers use it.
        libc = getLibc self;

        # Unfortunately, when building gcc in the next stage, its LTO plugin
        # would use the final libc but `ld` would use the bootstrap one,
        # and that can fail to load.  Therefore we upgrade `ld` to use newer libc;
        # apparently the interpreter needs to match libc, too.
        bintools = self.stdenvNoCC.mkDerivation {
          pname = prevStage.bintools.bintools.pname + "-patchelfed-ld";
          inherit (prevStage.bintools.bintools) version;
          passthru = { inherit (prevStage.bintools.passthru) isFromBootstrapFiles; };
          enableParallelBuilding = true;
          dontUnpack = true;
          dontBuild = true;
          strictDeps = true;
          # We wouldn't need to *copy* all, but it's easier and the result is temporary anyway.
          installPhase = ''
            mkdir -p "$out"/bin
            cp -a '${prevStage.bintools.bintools}'/bin/* "$out"/bin/
            chmod +w "$out"/bin/ld.bfd
            patchelf --set-interpreter '${getLibc self}'/lib/ld*.so.? \
              --set-rpath "${getLibc self}/lib:$(patchelf --print-rpath "$out"/bin/ld.bfd)" \
              "$out"/bin/ld.bfd
          '';
        };
      };

      # TODO(amjoseph): It is not yet entirely clear why this is necessary.
      # Something strange is going on with xgcc and libstdc++ on pkgsMusl.
      patchelf = super.patchelf.overrideAttrs(previousAttrs:
        lib.optionalAttrs super.stdenv.hostPlatform.isMusl {
          NIX_CFLAGS_COMPILE = (previousAttrs.NIX_CFLAGS_COMPILE or "") + " -static-libstdc++";
        });

    };

    # `gettext` comes with obsolete config.sub/config.guess that don't recognize LoongArch64.
    # `libtool` comes with obsolete config.sub/config.guess that don't recognize Risc-V.
    extraNativeBuildInputs = [ prevStage.updateAutotoolsGnuConfigScriptsHook ];
  })


  # Construct a third stdenv identical to the 2nd, except that this
  # one uses the rebuilt Glibc from stage2.  It still uses the recent
  # binutils and rest of the bootstrap tools, including GCC.
  (prevStage:
    # previous stage2 stdenv:
    assert        isBuiltByNixpkgsCompiler prevStage.binutils-unwrapped;
    assert        isBuiltByNixpkgsCompiler prevStage.${localSystem.libc};
    assert isBuiltByBootstrapFilesCompiler prevStage.gcc-unwrapped;
    assert            isFromBootstrapFiles prevStage.coreutils;
    assert            isFromBootstrapFiles prevStage.gnugrep;
    assert        isBuiltByNixpkgsCompiler prevStage.patchelf;
    assert lib.all isBuiltByNixpkgsCompiler [ prevStage.gmp prevStage.isl_0_20 prevStage.libmpc prevStage.mpfr ];
    stageFun prevStage {
    name = "bootstrap-stage3";

    overrides = self: super: rec {
      inherit (prevStage)
        ccWrapperStdenv
        binutils coreutils gnugrep gettext
        perl patchelf linuxHeaders gnum4 bison libidn2 libunistring libxcrypt;
        # We build a special copy of libgmp which doesn't use libstdc++, because
        # xgcc++'s libstdc++ references the bootstrap-files (which is what
        # compiles xgcc++).
        gmp = super.gmp.override { cxx = false; };
      } // {
      ${localSystem.libc} = getLibc prevStage;
      gcc-unwrapped = (super.gcc-unwrapped.override (commonGccOverrides // {
        inherit (prevStage) which;
      }
      )).overrideAttrs (a: {
        # so we can add them to allowedRequisites below
        passthru = a.passthru // { inherit (self) gmp mpfr libmpc isl; };
      });
    };
    extraNativeBuildInputs = [
      prevStage.patchelf
      # Many tarballs come with obsolete config.sub/config.guess that don't recognize aarch64.
      prevStage.updateAutotoolsGnuConfigScriptsHook
    ];
  })


  # Construct a fourth stdenv that uses the new GCC.  But coreutils is
  # still from the bootstrap tools.
  #
  (prevStage:
    # previous stage3 stdenv:
    assert isBuiltByNixpkgsCompiler prevStage.binutils-unwrapped;
    assert isBuiltByNixpkgsCompiler prevStage.${localSystem.libc};
    assert isBuiltByNixpkgsCompiler prevStage.gcc-unwrapped;
    assert     isFromBootstrapFiles prevStage.coreutils;
    assert     isFromBootstrapFiles prevStage.gnugrep;
    assert isBuiltByNixpkgsCompiler prevStage.patchelf;
    stageFun prevStage {
    name = "bootstrap-stage4";

    overrides = self: super: {
      # Zlib has to be inherited and not rebuilt in this stage,
      # because gcc (since JAR support) already depends on zlib, and
      # then if we already have a zlib we want to use that for the
      # other purposes (binutils and top-level pkgs) too.
      inherit (prevStage) gettext gnum4 bison perl texinfo zlib linuxHeaders libidn2 libunistring;
      ${localSystem.libc} = getLibc prevStage;
      # Since this is the first fresh build of binutils since stage2, our own runtimeShell will be used.
      binutils = super.binutils.override {
        # Build expand-response-params with last stage like below
        inherit (prevStage) expand-response-params;
      };

      # To allow users' overrides inhibit dependencies too heavy for
      # bootstrap, like guile: https://github.com/NixOS/nixpkgs/issues/181188
      gnumake = super.gnumake.override { inBootstrap = true; };

      gcc = lib.makeOverridable (import ../../build-support/cc-wrapper) {
        nativeTools = false;
        nativeLibc = false;
        isGNU = true;
        inherit (prevStage) expand-response-params;
        cc = prevStage.gcc-unwrapped;
        bintools = self.binutils;
        libc = getLibc self;
        inherit lib;
        inherit (self) stdenvNoCC coreutils gnugrep runtimeShell;
        fortify-headers = self.fortify-headers;
      };
    };
    extraNativeBuildInputs = [
      prevStage.patchelf prevStage.xz
      # Many tarballs come with obsolete config.sub/config.guess that don't recognize aarch64.
      prevStage.updateAutotoolsGnuConfigScriptsHook
    ];
  })

  # Construct the final stdenv.  It uses the Glibc and GCC, and adds
  # in a new binutils that doesn't depend on bootstrap-tools, as well
  # as dynamically linked versions of all other tools.
  #
  # When updating stdenvLinux, make sure that the result has no
  # dependency (`nix-store -qR') on bootstrapTools or the first
  # binutils built.
  #
  (prevStage:
    # previous stage4 stdenv; see stage3 comment regarding gcc,
    # which applies here as well.
    assert isBuiltByNixpkgsCompiler prevStage.binutils-unwrapped;
    assert isBuiltByNixpkgsCompiler prevStage.${localSystem.libc};
    assert isBuiltByNixpkgsCompiler prevStage.gcc-unwrapped;
    assert isBuiltByNixpkgsCompiler prevStage.coreutils;
    assert isBuiltByNixpkgsCompiler prevStage.gnugrep;
    assert isBuiltByNixpkgsCompiler prevStage.patchelf;
    {
    inherit config overlays;
    stdenv = import ../generic rec {
      name = "stdenv-linux";

      buildPlatform = localSystem;
      hostPlatform = localSystem;
      targetPlatform = localSystem;
      inherit config;

      preHook = commonPreHook;

      initialPath =
        ((import ../generic/common-path.nix) {pkgs = prevStage;});

      extraNativeBuildInputs = [
        prevStage.patchelf
        # Many tarballs come with obsolete config.sub/config.guess that don't recognize aarch64.
        prevStage.updateAutotoolsGnuConfigScriptsHook
      ];

      cc = prevStage.gcc;

      shell = cc.shell;

      inherit (prevStage.stdenv) fetchurlBoot;

      extraAttrs = {
        inherit bootstrapTools;
        shellPackage = prevStage.bash;
      };

      disallowedRequisites = [ bootstrapTools.out ];

      # Mainly avoid reference to bootstrap tools
      allowedRequisites = let
        inherit (prevStage) gzip bzip2 xz zlib bash binutils coreutils diffutils findutils
          gawk gmp gnumake gnused gnutar gnugrep gnupatch patchelf ed file glibc
          attr acl libidn2 libunistring linuxHeaders gcc fortify-headers gcc-unwrapped
          ;
      in
        # Simple executable tools
        lib.concatMap (p: [ (lib.getBin p) (lib.getLib p) ]) [
            gzip bzip2 xz bash binutils.bintools coreutils diffutils findutils
            gawk gmp gnumake gnused gnutar gnugrep gnupatch patchelf ed file
          ]
        # Library dependencies
        ++ map lib.getLib [ attr acl zlib gnugrep.pcre2 libidn2 libunistring ]
        # More complicated cases
        ++ (map (x: lib.getOutput x (getLibc prevStage)) [ "out" "dev" "bin" ] )
        ++  [ linuxHeaders # propagated from .dev
              binutils gcc gcc.cc gcc.cc.lib
              gcc.expand-response-params # != (prevStage.)expand-response-params
              gcc.cc.libgcc glibc.passthru.libgcc
          ]
        ++ lib.optionals (localSystem.libc == "musl") [ fortify-headers ]
        ++ [ prevStage.updateAutotoolsGnuConfigScriptsHook prevStage.gnu-config ]
        ++ [
          gcc-unwrapped.gmp gcc-unwrapped.libmpc gcc-unwrapped.mpfr gcc-unwrapped.isl
        ]
      ;

      overrides = self: super: {
        inherit (prevStage)
          gzip bzip2 xz bash coreutils diffutils findutils gawk
          gnused gnutar gnugrep gnupatch patchelf
          attr acl zlib libunistring;
        inherit (prevStage.gnugrep) pcre2;
        ${localSystem.libc} = getLibc prevStage;

        # Hack: avoid libidn2.{bin,dev} referencing bootstrap tools.  There's a logical cycle.
        libidn2 = import ../../development/libraries/libidn2/no-bootstrap-reference.nix {
          inherit lib;
          inherit (prevStage) libidn2;
          inherit (self) stdenv runCommandLocal patchelf libunistring;
        };

        gnumake = super.gnumake.override { inBootstrap = false; };
      } // lib.optionalAttrs (super.stdenv.targetPlatform == localSystem) {
        # Need to get rid of these when cross-compiling.
        inherit (prevStage) binutils binutils-unwrapped;
        gcc = cc;
      };
    };
  })

  # This "no-op" stage is just a place to put the assertions about stage5.
  (prevStage:
    # previous stage5 stdenv; see stage3 comment regarding gcc,
    # which applies here as well.
    assert isBuiltByNixpkgsCompiler prevStage.binutils-unwrapped;
    assert isBuiltByNixpkgsCompiler prevStage.${localSystem.libc};
    assert isBuiltByNixpkgsCompiler prevStage.gcc-unwrapped;
    assert isBuiltByNixpkgsCompiler prevStage.coreutils;
    assert isBuiltByNixpkgsCompiler prevStage.gnugrep;
    assert isBuiltByNixpkgsCompiler prevStage.patchelf;
    { inherit (prevStage) config overlays stdenv; })
]