pref("general.smoothScroll", true);
pref("general.smoothScroll.msdPhysics.enabled", true);
pref("general.smoothScroll.msdPhysics.continuousMotionMaxDeltaMS", 12);
pref("general.smoothScroll.msdPhysics.motionBeginSpringConstant", 600);
pref("general.smoothScroll.msdPhysics.regularSpringConstant", 650);
pref("general.smoothScroll.msdPhysics.slowdownMinDeltaMS", 25);
pref("general.smoothScroll.msdPhysics.slowdownSpringConstant", 250);
pref("mousewheel.default.delta_multiplier_y", 300);
pref("browser.toolbars.bookmarks.visibility", "newtab");
pref("sidebar.revamp", true);
pref("sidebar.verticalTabs", true);
pref("sidebar.visibility", "always-show");
pref("sidebar.position_start", true);

try {
  const { classes, interfaces } = Components;
  const observers = classes["@mozilla.org/observer-service;1"].getService(interfaces.nsIObserverService);

  const toggleTabs = (window) => window.SidebarController.handleToolbarButtonClick();

  const toggleRightPanel = (window) => {
    const sidebar = window.SidebarController;
    if (sidebar.isOpen) {
      sidebar.hide();
    } else {
      window.document.getElementById("sidebar-box").setAttribute("sidebar-positionend", "");
      sidebar.show(sidebar.lastOpenedId || "viewBookmarksSidebar");
    }
  };

  const actions = {
    "Alt+KeyH": (window) => window.gBrowser.goBack(),
    "Alt+KeyL": (window) => window.gBrowser.goForward(),
    "Alt+KeyJ": (window) => window.gBrowser.tabContainer.advanceSelectedTab(1, true),
    "Alt+KeyK": (window) => window.gBrowser.tabContainer.advanceSelectedTab(-1, true),
    "Alt+Shift+KeyJ": (window) => window.gBrowser.moveTabForward(),
    "Alt+Shift+KeyK": (window) => window.gBrowser.moveTabBackward(),
    "Ctrl+KeyB": toggleTabs,
    "Ctrl+Shift+KeyB": toggleRightPanel,
  };

  observers.addObserver(
    {
      observe(window) {
        window.addEventListener(
          "keydown",
          (event) => {
            if (event.metaKey) {
              return;
            }
            const key =
              (event.ctrlKey ? "Ctrl+" : "") +
              (event.altKey ? "Alt+" : "") +
              (event.shiftKey ? "Shift+" : "") +
              event.code;
            const action = actions[key];
            if (action) {
              event.preventDefault();
              event.stopImmediatePropagation();
              action(window);
            }
          },
          true
        );
      },
    },
    "browser-delayed-startup-finished"
  );

  const squares = `@-moz-document url-prefix("chrome://"), url-prefix("about:") {
    *, *::before, *::after { border-radius: 0 !important; }
  }
  @-moz-document url("chrome://browser/content/browser.xhtml") {
    #sidebar-splitter { order: 99 !important; }
    #sidebar-box { order: 100 !important; }
  }`;

  observers.addObserver(
    {
      observe() {
        const io = classes["@mozilla.org/network/io-service;1"].getService(interfaces.nsIIOService);
        const sheets = classes["@mozilla.org/content/style-sheet-service;1"].getService(interfaces.nsIStyleSheetService);
        sheets.loadAndRegisterSheet(
          io.newURI("data:text/css;charset=utf-8," + encodeURIComponent(squares)),
          sheets.USER_SHEET
        );
      },
    },
    "final-ui-startup"
  );
} catch {}
