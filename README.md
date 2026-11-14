# Paintshop

https://github.com/ac-custom-shaders-patch/app-paintshop/assets/3996502/0d2e1786-1222-472a-94f2-1f6553b1ac10

Paintshop app for drawing on cars in Assetto Corsa. Written in Lua, needs at least CSP 0.1.77 to work. Feel free to use as an example, fork and modify it or anything else.

# Features

- Various instruments like brushes, blurring and smudging tools;
- Different tools for mirroring;
- Pen pressure support;
- Hotkeys similar to Photoshop hotkeys;
- Easily extendable with new brushes, stickers, patterns and more.

# How to install

- [Download latest release](https://github.com/ac-custom-shaders-patch/app-paintshop/releases/latest/download/Paintshop.zip);
- Drag’n’drop it to Content Manager;
- Or, alternatively, copy apps folder from archive to AC root folder manually.

# How to use

- Select a white car skin with no patterns on it;
- Open the app, select car exterior by clicking on it while holding Shift;
- Start drawing;
- Once finished, export the result with button with a printer icon on it;
- Save your original work by using save button.

The reason for that workflow is because the app would use original texture as an AO map and apply it on top of the result. That’s why save and export are different functions: only export one would apply AO. If you’re loading existing texture with Open button, make sure to select a texture without AO.

Note: Open and Save buttons have context menus with extra options. Also, brush and stamp selection lists have context menus as well allowing to add new brushes and decals live.

# Known issues

- With new skidmarks tools such as projecting other side, mirroring stamp, blur and smudge might not work propely in 0.1.78, this issue will be fixed in 0.1.79.
- Context menus might misbehave and trigger button clicks with Discord fix enabled in general CSP settings. Again, will be fixed in 0.1.79.

# Code layout

`Paintshop.lua` is the entry point: it loads the modules, wires them together and forwards the
callbacks the manifest asks for. Everything else lives in three folders:

```
core/   environment, state, storage, canvases, history, projection, painting, session
tools/  one file per tool, plus the registry that owns the tool list
gui/    icons, palette, shared widgets, toolbar, tool panel, 3D gizmo
```

Dependency direction is `gui -> tools -> core -> AC API`. Nothing in `core/` may reference a
tool or a widget. `core/types.lua` documents the tool contract (which fields a tool must
provide, what `brushSize()` returns, when `procBrushTex()` may return nil, and so on).

Modules are loaded with `dofile()` against `__dirname` rather than `require()`, because the app
folder is not guaranteed to be on `package.path`.

# TODO

- Layers;
- Layer effects;
- Mask;
- Splines.
