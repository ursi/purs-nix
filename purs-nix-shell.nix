{ dependencies, deps-srcs, pkgs }:
{ src ? "src"
, output ? "output"
, bundle ? {}
, compile ? {}
, nodejs ? pkgs.nodejs
, purescript ? pkgs.purescript
}:
  let
    l = p.lib; p = pkgs; u = import ./utils.nix;
    command = "purs-nix";
    compiler-output = output;

    make-flag = flag: arg:
      if arg == null || arg == false then
        ""
      else if arg == true then
        flag
      else
        flag + arg;

    bundle-output-default = "index.js";

    bundle' =
      { module ? "Main"
      , output ? bundle-output-default
      , main ? module
      , namespace ? null
      , source-maps ? false
      , debug ? false
      }:
      let
        flags =
          builtins.concatStringsSep " "
            [ "--module ${module}"
              (make-flag "--output " output)
              (make-flag "--main " main)
              (make-flag "--namespace " namespace)
              (make-flag "--source-maps" source-maps)
              (make-flag "debug" debug)
            ];
      in
      ''
      ${command} compile \
        && ${purescript}/bin/purs bundle ${flags} "${compiler-output}/**/*.js"'';

    compile' =
      { verbose-errors ? false
      , comments ? false
      , codegen ? null
      , no-prefix ? false
      , json-errors ? false
      }:
      let
        flags =
          builtins.concatStringsSep " "
            [ (make-flag "--output " output)
              (make-flag "--verbose-errors" verbose-errors)
              (make-flag "--comments" comments)
              (make-flag "--codegen " codegen)
              (make-flag "--no-prefix" no-prefix)
              (make-flag "--json-errors" no-prefix)
            ];
      in
      ''${purescript}/bin/purs compile ${flags} "${src}/**/*.purs" ${deps-srcs}'';

    package-info =
      p.writeShellScript "package-info"
        ''
        case $1 in

        ${builtins.concatStringsSep "\n"
            (builtins.map
               (pkg: "${pkg.pname or pkg.name} ) ${u.package-info pkg};;")
               dependencies
            )
        }

        * ) echo "There is no package in your project with the name '$1'.";;
        esac
        '';

    packages =
      p.writeShellScript "packages"
        ''
        ${builtins.concatStringsSep "\n"
            (builtins.map
               (pkg: "echo ${pkg.name}")
               dependencies
            )
        }
        '';
    help =
      l.escapeShellArg
        ''
        purs-nix <command>

        Commands:
        ------------------------------------------------------------------------
        compile    Compile your project.
        bundle     Compile then bundle your project.
        run        Compile, bundle, then run the bundle with 'node'.
        ------------------------------------------------------------------------
        package-info <name>    Show the info of a specific package.
        packages               Show the info of all the packages in your project.
        -------------------------------------------------------------------------
        output <args>    Pass arguments to 'purs' with the glob for your
                         compiled code passed as the final argument.

        srcs <args>      Pass arguments to 'purs' with the globs for your
                         projects's PureScript source code passed as the
                         final argument.
        -------------------------------------------------------------------------

        Anything that is not a valid command with show this text.
        '';

    run-output = ".purs-nix-run.js";
  in
  p.writeShellScriptBin "purs-nix"
    ''
    case $1 in
      compile ) ${compile' compile};;
      bundle ) ${bundle' bundle};;
      run )
        ${bundle' (bundle // { output = run-output; })} \
          && ${nodejs}/bin/node ${run-output};;
      package-info ) ${package-info} $2;;
      packages ) ${packages};;
      output ) ${purescript}/bin/purs ''${@:2} "${compiler-output}/**/*.js";;
      srcs ) ${purescript}/bin/purs ''${@:2} "${src}/**/*.purs" ${deps-srcs};;
      * ) echo ${help};;
    esac
    ''
