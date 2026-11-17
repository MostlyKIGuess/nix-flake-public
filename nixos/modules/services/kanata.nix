{ ... }:
{
  services.kanata = {
    enable = true;
    keyboards.default = {
      devices = [ ];
      extraDefCfg = "process-unmapped-keys yes";
      config = ''
        (defsrc
          slck
        )

        (deflayer base
          slck
        )

        (defoverridesv2
          (lalt j) (pgdn) (lsft rsft lctl rctl) ()
          (lalt k) (pgup) (lsft rsft lctl rctl) ()
          (lctl lalt lsft j) (lctl lsft pgdn) () ()
          (lctl lalt lsft k) (lctl lsft pgup) () ()
        )
      '';
    };
  };
}
