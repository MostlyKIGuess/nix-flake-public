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

        (defoverrides
          (lalt j) (pgdn)
          (lalt k) (pgup)
        )
      '';
    };
  };
}
