{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default = {
      mutableUserSettings = true;
      userSettings = ./settings.json;
      extensions =
        with pkgs.vscode-extensions;
        [
          vscodevim.vim
          pkief.material-icon-theme
          ms-python.python
          ms-python.vscode-pylance
          ms-python.debugpy
          ms-python.vscode-python-envs
          ms-toolsai.jupyter
          ms-toolsai.jupyter-keymap
          ms-toolsai.jupyter-renderers
          ms-toolsai.vscode-jupyter-cell-tags
          ms-toolsai.vscode-jupyter-slideshow
          hediet.vscode-drawio
          tomoki1207.pdf
        ]
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            publisher = "pomdtr";
            name = "excalidraw-editor";
            version = "3.9.3";
            hash = "sha256-2K2LF7J6yaogHQjtA60qRL/m1g5gKtDl7XR4PBtEcUk=";
          }
          {
            publisher = "kleinicke";
            name = "ply-visualizer";
            version = "1.8.1";
            hash = "sha256-ZpryvAL9lBtr+tMWoTHuuWJIfyv6BIX0C+XCNBzb7zU=";
          }
        ];
      keybindings =
        let
          when = "(sideBarFocus || auxiliaryBarFocus || panelFocus || activeEditorGroupEmpty) && !terminalFocus && !inputFocus && !editorTextFocus";
          nav = key: dir: {
            key = "ctrl+w ${key}";
            command = "workbench.action.navigate${dir}";
            inherit when;
          };
        in
        [
          (nav "h" "Left")
          (nav "j" "Down")
          (nav "k" "Up")
          (nav "l" "Right")
        ];
    };
  };
}
