module biotronic.DCC.util.windowenums;

import biotronic.DCC.util.flags;

alias  Flags!("
	Overlapped       = 0x00000000,
	Tiled            = Overlapped,
	MaximizeBox      = 0x00010000,
	MinimizeBox      = 0x00020000,
	TabStop          = 0x00010000,
	Group            = 0x00020000,
	ThickFrame       = 0x00040000,
	SizeBox          = ThickFrame,
	SysMenu          = 0x00080000,
	HScroll          = 0x00100000,
	VScroll          = 0x00200000,
	DlgFrame         = 0x00400000,
	Border           = 0x00800000,
	Caption          = 0x00c00000,
	OverlappedWindow = Overlapped | Caption | SysMenu | ThickFrame | MinimizeBox | MaximizeBox,
	TiledWindow      = OverlappedWindow,
	Maximize         = 0x01000000,
	ClipChildren     = 0x02000000,
	ClipSiblings     = 0x04000000,
	Disabled         = 0x08000000,
	Visible          = 0x10000000,
	Minimize         = 0x20000000,
	Iconic           = Minimize,
	Child            = 0x40000000,
	ChildWindow      = 0x40000000,
	Popup            = 0x80000000,
	PopupWindow      = Popup | Border | SysMenu,
", false) WsStyles;

alias  Flags!("
    Left             = 0x0000_0000,
    LtrReading       = 0x0000_0000,
    RightScrollbar   = 0x0000_0000,
    DlgModalFrame    = 0x0000_0001,
    Transparent      = 0x0000_0002,
    NoParentNotify   = 0x0000_0004,
    TopMost          = 0x0000_0008,
    AcceptFiles      = 0x0000_0010,
    MdiChild         = 0x0000_0040,
    ToolWindow       = 0x0000_0080,
    WindowEdge       = 0x0000_0100,
    PaletteWindow    = WindowEdge | ToolWindow | TopMost,
    ClientEdge       = 0x0000_0200,
    OverlappedWindow = ClientEdge | WindowEdge,
    ContextHelp      = 0x0000_0400,
    Right            = 0x0000_1000,
    RtlReading       = 0x0000_2000,
    LeftScrollbar    = 0x0000_4000,
    ControlParent    = 0x0001_0000,
    StaticEdge       = 0x0002_0000,
    AppWindow        = 0x0004_0000,
    Layered          = 0x0008_0000, // w2k
    NoInheritLayout  = 0x0010_0000, // w2k
    LayoutRtl        = 0x0040_0000, // w98, w2k
    Composited       = 0x0200_0000, // XP
	NoActivate       = 0x0800_0000, // w2k
", false) WsExStyles;