{
    lib,
    rustPlatform,
    wireguard-tools
}:

rustPlatform.buildRustPackage (finalAttrs: {
    pname = "wg-homepage";
    version = "0.1.0";

    src = ./.;

    postPatch = ''
      substituteInPlace src/main.rs \
        --replace-fail '"wg",//command' '"${wireguard-tools}/bin/wg",'
    '';

    cargoHash = "sha256-uSC+1nvndnPgxdc5wuhSW0s8Jn3nBZ4Rtu5L3beDWGQ=";

    meta = {
      description = "Service to query wg, and provide that as an api for homepage-dashboard";
      homepage = "https://github.com/nofishleft/wg-homepage";
      license = lib.licenses.sustainableUse;
    };
})