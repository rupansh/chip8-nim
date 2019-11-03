import sdl2/sdl

type Display* = object
    window*: Window
    renderer*: Renderer
    texture*: Texture


proc displayInit*(display: var Display) =
    discard sdl.init(INIT_VIDEO)

    display.window = createWindow("chip-8 emu", WINDOWPOS_UNDEFINED, WINDOWPOS_UNDEFINED, 640, 320, WINDOW_SHOWN)

    display.renderer = createRenderer(display.window, -1, RENDERER_ACCELERATED)

    display.texture = createTexture(display.renderer, PIXELFORMAT_ARGB8888, TEXTUREACCESS_STATIC, 64, 32)


proc displayDraw*(display: var Display, pixels: var array[2048, uint32]) =
    discard updateTexture(display.texture, nil, addr pixels, 64*sizeof(uint32))
    discard renderCopy(display.renderer, display.texture, nil, nil)
    renderPresent(display.renderer)

proc displayClean*(display: var Display) =
    destroyTexture(display.texture)
    destroyRenderer(display.renderer)
    destroyWindow(display.window)
    sdl.quit()