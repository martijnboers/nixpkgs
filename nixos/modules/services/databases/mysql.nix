{ config, lib, pkgs, ... }:
let

  cfg = config.services.mysql;

  isMariaDB = lib.getName cfg.package == lib.getName pkgs.mariadb;
  isOracle = lib.getName cfg.package == lib.getName pkgs.mysql80;
  # Oracle MySQL has supported "notify" service type since 8.0
  hasNotify = isMariaDB || (isOracle && lib.versionAtLeast cfg.package.version "8.0");

  mysqldOptions =
    "--user=${cfg.user} --datadir=${cfg.dataDir} --basedir=${cfg.package}";

  format = pkgs.formats.ini { listsAsDuplicateKeys = true; };
  configFile = format.generate "my.cnf" cfg.settings;

in

{
  imports = [
    (lib.mkRemovedOptionModule [ "services" "mysql" "pidDir" ] "Don't wait for pidfiles, describe dependencies through systemd.")
    (lib.mkRemovedOptionModule [ "services" "mysql" "rootPassword" ] "Use socket authentication or set the password outside of the nix store.")
    (lib.mkRemovedOptionModule [ "services" "mysql" "extraOptions" ] "Use services.mysql.settings.mysqld instead.")
    (lib.mkRemovedOptionModule [ "services" "mysql" "bind" ] "Use services.mysql.settings.mysqld.bind-address instead.")
    (lib.mkRemovedOptionModule [ "services" "mysql" "port" ] "Use services.mysql.settings.mysqld.port instead.")
  ];

  ###### interface

  options = {

    services.mysql = {

      enable = lib.mkEnableOption "MySQL server";

      package = lib.mkOption {
        type = lib.types.package;
        example = lib.literalExpression "pkgs.mariadb";
        description = ''
          Which MySQL derivation to use. MariaDB packages are supported too.
        '';
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "mysql";
        description = ''
          User account under which MySQL runs.

          ::: {.note}
          If left as the default value this user will automatically be created
          on system activation, otherwise you are responsible for
          ensuring the user exists before the MySQL service starts.
          :::
        '';
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "mysql";
        description = ''
          Group account under which MySQL runs.

          ::: {.note}
          If left as the default value this group will automatically be created
          on system activation, otherwise you are responsible for
          ensuring the user exists before the MySQL service starts.
          :::
        '';
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        example = "/var/lib/mysql";
        description = ''
          The data directory for MySQL.

          ::: {.note}
          If left as the default value of `/var/lib/mysql` this directory will automatically be created before the MySQL
          server starts, otherwise you are responsible for ensuring the directory exists with appropriate ownership and permissions.
          :::
        '';
      };

      configFile = lib.mkOption {
        type = lib.types.path;
        default = configFile;
        defaultText = ''
          A configuration file automatically generated by NixOS.
        '';
        description = ''
          Override the configuration file used by MySQL. By default,
          NixOS generates one automatically from {option}`services.mysql.settings`.
        '';
        example = lib.literalExpression ''
          pkgs.writeText "my.cnf" '''
            [mysqld]
            datadir = /var/lib/mysql
            bind-address = 127.0.0.1
            port = 3336

            !includedir /etc/mysql/conf.d/
          ''';
        '';
      };

      settings = lib.mkOption {
        type = format.type;
        default = {};
        description = ''
          MySQL configuration. Refer to
          <https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html>,
          <https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html>,
          and <https://mariadb.com/kb/en/server-system-variables/>
          for details on supported values.

          ::: {.note}
          MySQL configuration options such as `--quick` should be treated as
          boolean options and provided values such as `true`, `false`,
          `1`, or `0`. See the provided example below.
          :::
        '';
        example = lib.literalExpression ''
          {
            mysqld = {
              key_buffer_size = "6G";
              table_cache = 1600;
              log-error = "/var/log/mysql_err.log";
              plugin-load-add = [ "server_audit" "ed25519=auth_ed25519" ];
            };
            mysqldump = {
              quick = true;
              max_allowed_packet = "16M";
            };
          }
        '';
      };

      initialDatabases = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = ''
                The name of the database to create.
              '';
            };
            schema = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = ''
                The initial schema of the database; if null (the default),
                an empty database is created.
              '';
            };
          };
        });
        default = [];
        description = ''
          List of database names and their initial schemas that should be used to create databases on the first startup
          of MySQL. The schema attribute is optional: If not specified, an empty database is created.
        '';
        example = lib.literalExpression ''
          [
            { name = "foodatabase"; schema = ./foodatabase.sql; }
            { name = "bardatabase"; }
          ]
        '';
      };

      initialScript = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "A file containing SQL statements to be executed on the first startup. Can be used for granting certain permissions on the database.";
      };

      ensureDatabases = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Ensures that the specified databases exist.
          This option will never delete existing databases, especially not when the value of this
          option is changed. This means that databases created once through this option or
          otherwise have to be removed manually.
        '';
        example = [
          "nextcloud"
          "matomo"
        ];
      };

      ensureUsers = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = ''
                Name of the user to ensure.
              '';
            };
            ensurePermissions = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = {};
              description = ''
                Permissions to ensure for the user, specified as attribute set.
                The attribute names specify the database and tables to grant the permissions for,
                separated by a dot. You may use wildcards here.
                The attribute values specfiy the permissions to grant.
                You may specify one or multiple comma-separated SQL privileges here.

                For more information on how to specify the target
                and on which privileges exist, see the
                [GRANT syntax](https://mariadb.com/kb/en/library/grant/).
                The attributes are used as `GRANT ''${attrName} ON ''${attrValue}`.
              '';
              example = lib.literalExpression ''
                {
                  "database.*" = "ALL PRIVILEGES";
                  "*.*" = "SELECT, LOCK TABLES";
                }
              '';
            };
          };
        });
        default = [];
        description = ''
          Ensures that the specified users exist and have at least the ensured permissions.
          The MySQL users will be identified using Unix socket authentication. This authenticates the Unix user with the
          same name only, and that without the need for a password.
          This option will never delete existing users or remove permissions, especially not when the value of this
          option is changed. This means that users created and permissions assigned once through this option or
          otherwise have to be removed manually.
        '';
        example = lib.literalExpression ''
          [
            {
              name = "nextcloud";
              ensurePermissions = {
                "nextcloud.*" = "ALL PRIVILEGES";
              };
            }
            {
              name = "backup";
              ensurePermissions = {
                "*.*" = "SELECT, LOCK TABLES";
              };
            }
          ]
        '';
      };

      replication = {
        role = lib.mkOption {
          type = lib.types.enum [ "master" "slave" "none" ];
          default = "none";
          description = "Role of the MySQL server instance.";
        };

        serverId = lib.mkOption {
          type = lib.types.int;
          default = 1;
          description = "Id of the MySQL server instance. This number must be unique for each instance.";
        };

        masterHost = lib.mkOption {
          type = lib.types.str;
          description = "Hostname of the MySQL master server.";
        };

        slaveHost = lib.mkOption {
          type = lib.types.str;
          description = "Hostname of the MySQL slave server.";
        };

        masterUser = lib.mkOption {
          type = lib.types.str;
          description = "Username of the MySQL replication user.";
        };

        masterPassword = lib.mkOption {
          type = lib.types.str;
          description = "Password of the MySQL replication user.";
        };

        masterPort = lib.mkOption {
          type = lib.types.port;
          default = 3306;
          description = "Port number on which the MySQL master server runs.";
        };
      };
    };

  };


  ###### implementation

  config = lib.mkIf cfg.enable {

    services.mysql.dataDir =
      lib.mkDefault (if lib.versionAtLeast config.system.stateVersion "17.09" then "/var/lib/mysql"
                 else "/var/mysql");

    services.mysql.settings.mysqld = lib.mkMerge [
      {
        datadir = cfg.dataDir;
        port = lib.mkDefault 3306;
      }
      (lib.mkIf (cfg.replication.role == "master" || cfg.replication.role == "slave") {
        log-bin = "mysql-bin-${toString cfg.replication.serverId}";
        log-bin-index = "mysql-bin-${toString cfg.replication.serverId}.index";
        relay-log = "mysql-relay-bin";
        server-id = cfg.replication.serverId;
        binlog-ignore-db = [ "information_schema" "performance_schema" "mysql" ];
      })
      (lib.mkIf (!isMariaDB) {
        plugin-load-add = "auth_socket.so";
      })
    ];

    users.users = lib.optionalAttrs (cfg.user == "mysql") {
      mysql = {
        description = "MySQL server user";
        group = cfg.group;
        uid = config.ids.uids.mysql;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "mysql") {
      mysql.gid = config.ids.gids.mysql;
    };

    environment.systemPackages = [ cfg.package ];

    environment.etc."my.cnf".source = cfg.configFile;

    # The mysql_install_db binary will try to adjust the permissions, but fail to do so with a permission
    # denied error in some circumstances. Setting the permissions manually with tmpfiles is a workaround.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.mysql = {
      description = "MySQL Server";

      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ cfg.configFile ];

      unitConfig.RequiresMountsFor = cfg.dataDir;

      path = [
        # Needed for the mysql_install_db command in the preStart script
        # which calls the hostname command.
        pkgs.nettools
      ];

      preStart = if isMariaDB then ''
        if ! test -e ${cfg.dataDir}/mysql; then
          ${cfg.package}/bin/mysql_install_db --defaults-file=/etc/my.cnf ${mysqldOptions}
          touch ${cfg.dataDir}/mysql_init
        fi
      '' else ''
        if ! test -e ${cfg.dataDir}/mysql; then
          ${cfg.package}/bin/mysqld --defaults-file=/etc/my.cnf ${mysqldOptions} --initialize-insecure
          touch ${cfg.dataDir}/mysql_init
        fi
      '';

      script = ''
        # https://mariadb.com/kb/en/getting-started-with-mariadb-galera-cluster/#systemd-and-galera-recovery
        if test -n "''${_WSREP_START_POSITION}"; then
          if test -e "${cfg.package}/bin/galera_recovery"; then
            VAR=$(cd ${cfg.package}/bin/..; ${cfg.package}/bin/galera_recovery); [[ $? -eq 0 ]] && export _WSREP_START_POSITION=$VAR || exit 1
          fi
        fi

        # The last two environment variables are used for starting Galera clusters
        exec ${cfg.package}/bin/mysqld --defaults-file=/etc/my.cnf ${mysqldOptions} $_WSREP_NEW_CLUSTER $_WSREP_START_POSITION
      '';

      postStart = let
        # The super user account to use on *first* run of MySQL server
        superUser = if isMariaDB then cfg.user else "root";
      in ''
        ${lib.optionalString (!hasNotify) ''
          # Wait until the MySQL server is available for use
          while [ ! -e /run/mysqld/mysqld.sock ]
          do
              echo "MySQL daemon not yet started. Waiting for 1 second..."
              sleep 1
          done
        ''}

        if [ -f ${cfg.dataDir}/mysql_init ]
        then
            # While MariaDB comes with a 'mysql' super user account since 10.4.x, MySQL does not
            # Since we don't want to run this service as 'root' we need to ensure the account exists on first run
            ( echo "CREATE USER IF NOT EXISTS '${cfg.user}'@'localhost' IDENTIFIED WITH ${if isMariaDB then "unix_socket" else "auth_socket"};"
              echo "GRANT ALL PRIVILEGES ON *.* TO '${cfg.user}'@'localhost' WITH GRANT OPTION;"
            ) | ${cfg.package}/bin/mysql -u ${superUser} -N

            ${lib.concatMapStrings (database: ''
              # Create initial databases
              if ! test -e "${cfg.dataDir}/${database.name}"; then
                  echo "Creating initial database: ${database.name}"
                  ( echo 'create database `${database.name}`;'

                    ${lib.optionalString (database.schema != null) ''
                    echo 'use `${database.name}`;'

                    # TODO: this silently falls through if database.schema does not exist,
                    # we should catch this somehow and exit, but can't do it here because we're in a subshell.
                    if [ -f "${database.schema}" ]
                    then
                        cat ${database.schema}
                    elif [ -d "${database.schema}" ]
                    then
                        cat ${database.schema}/mysql-databases/*.sql
                    fi
                    ''}
                  ) | ${cfg.package}/bin/mysql -u ${superUser} -N
              fi
            '') cfg.initialDatabases}

            ${lib.optionalString (cfg.replication.role == "master")
              ''
                # Set up the replication master

                ( echo "use mysql;"
                  echo "CREATE USER '${cfg.replication.masterUser}'@'${cfg.replication.slaveHost}' IDENTIFIED WITH mysql_native_password;"
                  echo "SET PASSWORD FOR '${cfg.replication.masterUser}'@'${cfg.replication.slaveHost}' = PASSWORD('${cfg.replication.masterPassword}');"
                  echo "GRANT REPLICATION SLAVE ON *.* TO '${cfg.replication.masterUser}'@'${cfg.replication.slaveHost}';"
                ) | ${cfg.package}/bin/mysql -u ${superUser} -N
              ''}

            ${lib.optionalString (cfg.replication.role == "slave")
              ''
                # Set up the replication slave

                ( echo "stop slave;"
                  echo "change master to master_host='${cfg.replication.masterHost}', master_user='${cfg.replication.masterUser}', master_password='${cfg.replication.masterPassword}';"
                  echo "start slave;"
                ) | ${cfg.package}/bin/mysql -u ${superUser} -N
              ''}

            ${lib.optionalString (cfg.initialScript != null)
              ''
                # Execute initial script
                # using toString to avoid copying the file to nix store if given as path instead of string,
                # as it might contain credentials
                cat ${toString cfg.initialScript} | ${cfg.package}/bin/mysql -u ${superUser} -N
              ''}

            rm ${cfg.dataDir}/mysql_init
        fi

        ${lib.optionalString (cfg.ensureDatabases != []) ''
          (
          ${lib.concatMapStrings (database: ''
            echo "CREATE DATABASE IF NOT EXISTS \`${database}\`;"
          '') cfg.ensureDatabases}
          ) | ${cfg.package}/bin/mysql -N
        ''}

        ${lib.concatMapStrings (user:
          ''
            ( echo "CREATE USER IF NOT EXISTS '${user.name}'@'localhost' IDENTIFIED WITH ${if isMariaDB then "unix_socket" else "auth_socket"};"
              ${lib.concatStringsSep "\n" (lib.mapAttrsToList (database: permission: ''
                echo "GRANT ${permission} ON ${database} TO '${user.name}'@'localhost';"
              '') user.ensurePermissions)}
            ) | ${cfg.package}/bin/mysql -N
          '') cfg.ensureUsers}
      '';

      serviceConfig = lib.mkMerge [
        {
          Type = if hasNotify then "notify" else "simple";
          Restart = "on-abort";
          RestartSec = "5s";

          # User and group
          User = cfg.user;
          Group = cfg.group;
          # Runtime directory and mode
          RuntimeDirectory = "mysqld";
          RuntimeDirectoryMode = "0755";
          # Access write directories
          ReadWritePaths = [ cfg.dataDir ];
          # Capabilities
          CapabilityBoundingSet = "";
          # Security
          NoNewPrivileges = true;
          # Sandboxing
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHostname = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          PrivateMounts = true;
          # System Call Filtering
          SystemCallArchitectures = "native";
        }
        (lib.mkIf (cfg.dataDir == "/var/lib/mysql") {
          StateDirectory = "mysql";
          StateDirectoryMode = "0700";
        })
      ];
    };
  };
}