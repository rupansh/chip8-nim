import display

import sdl2/sdl
import strutils
import random
import constants

type system* = object
    mem*: array[4096, byte] # chip-8 has 4K memory
    reg*: array[16, byte] # chip-8 has 16 registers
    I*: uint16
    pc*: uint16
    pix*: array[2048, uint32] # 64*32 screen
    delT*: byte
    delS*: byte
    stack*: array[16, uint16]
    sp*: uint16
    draw*: bool


proc initSystem(): system =
    var ourSys = system(I: 0, pc: 0x200, delT: 0, delS: 0, sp: 0, draw: false)

    for i in 0..<fontset.len:
        ourSys.mem[i] = fontset[i]

    return ourSys

proc loadGame(location: string, curSys: var system) =
    var data = location.readFile
    copyMem(addr curSys.mem[0x200], addr data[0], data.len)


proc emulate(curSys: var system) =
    let opcode = curSys.mem[curSys.pc].uint16 shl 8 or curSys.mem[curSys.pc + 1]
    var jump = false

    echo("opcode = 0x" & $opcode.toHex & " at " & $curSys.pc.toHex & " I= 0x" & $curSys.I.toHex & " SP= " & $curSys.sp)

    case opcode and 0xF000
    of 0x0000:
        case opcode and 0x000F
        of 0x0000: # clear display
            for pix in curSys.pix.mitems: pix = 0xFF000000.uint32
        of 0x000E: # return sp
            curSys.pc = curSys.stack[curSys.sp]
            curSys.stack[curSys.sp] = 0
            if curSys.sp != 0:
                curSys.sp -= 1
        else:
            echo("Unknown opcode 0x0000: 0x", opcode.toHex)
    of 0x1000: # jump to NNN
        jump = true
        curSys.pc = opcode and 0x0FFF
    of 0x2000: # call SP at NNN
        jump = true
        curSys.sp += 1
        curSys.stack[curSys.sp] = curSys.pc
        curSys.pc = opcode and 0x0FFF
    of 0x3000: # skip if VX == NNN
        if (curSys.reg[((opcode and 0x0F00) shr 8)]) == (opcode and 0xFF).byte:
            curSys.pc += 2
    of 0x4000: # skip if VN != NNN
        if (curSys.reg[((opcode and 0x0F00) shr 8)]) != (opcode and 0xFF).byte:
            curSys.pc += 2
    of 0x5000: # skip if VX == VY
        if (curSys.reg[((opcode and 0x0F00) shr 8)]) == (curSys.reg[((opcode and 0x00F0) shr 4)]):
            curSys.pc += 2
    of 0x6000: # VX = NN
        curSys.reg[((opcode and 0x0F00) shr 8)] = (opcode and 0xFF).byte
    of 0x7000: # VX += NNN
        curSys.reg[((opcode and 0x0F00) shr 8)] += (opcode and 0xFF).byte
    of 0x8000:
        case opcode and 0x000F
        of 0x0000: # VX = VY
            (curSys.reg[((opcode and 0x0F00) shr 8)]) = (curSys.reg[((opcode and 0x00F0) shr 4)])
        of 0x0001: # VX |= VY
            (curSys.reg[((opcode and 0x0F00) shr 8)]) = (curSys.reg[((opcode and 0x0F00) shr 8)]) or (curSys.reg[((opcode and 0x00F0) shr 4)])
        of 0x0002: # VX &= VY
            (curSys.reg[((opcode and 0x0F00) shr 8)]) = (curSys.reg[((opcode and 0x0F00) shr 8)]) and (curSys.reg[((opcode and 0x00F0) shr 4)])
        of 0x0003: # VX ^= VY
            (curSys.reg[((opcode and 0x0F00) shr 8)]) = (curSys.reg[((opcode and 0x0F00) shr 8)]) xor (curSys.reg[((opcode and 0x00F0) shr 4)])
        of 0x0004: # add regg VY to VX
            if curSys.reg[(opcode and 0x00F0) shr 4] < (256 - curSys.reg[(opcode and 0x0F00) shr 8]):
                curSys.reg[0xF] = curSys.reg[0xF] and 0.byte
            else:
                curSys.reg[0xF] = 1

            curSys.reg[(opcode and 0x0F00) shr 8] += curSys.reg[(opcode and 0x00F0) shr 4]
        of 0x0005: # VX -= VY
            if curSys.reg[(opcode and 0x00F0) shr 4] >= curSys.reg[(opcode and 0x0F00) shr 8]:
                curSys.reg[0xF] = 1 # set carry
            else:
                curSys.reg[0xF] = curSys.reg[0xF] and 0.byte

            curSys.reg[(opcode and 0x0F00) shr 8] -= curSys.reg[(opcode and 0x00F0) shr 4]
        of 0x0006: # shift right VX by 1
            let X = ((opcode and 0x0F00) shr 8)
            curSys.reg[0xF] = (curSys.reg[X] and 7).byte
            curSys.reg[X] = curSys.reg[X] shr 1
        of 0x0007: # VX = VY - VX
            if curSys.reg[(opcode and 0x00F0) shr 4] < curSys.reg[(opcode and 0x0F00) shr 8]:
                curSys.reg[0xF] = 1
            else:
                curSys.reg[0xF] = curSys.reg[0xF] and 0.byte

            curSys.reg[(opcode and 0x0F00) shr 8] = curSys.reg[(opcode and 0x00F0) shr 4] - curSys.reg[(opcode and 0x0F00) shr 8]
        of 0x000E: # shift left VX by 1
            let X = ((opcode and 0x0F00) shr 8)
            curSys.reg[0xF] = curSys.reg[X] shr 7
            curSys.reg[X] = curSys.reg[X] shl 1
        else:
            echo("unknown opcode 0d" & $opcode.toHex)
    of 0x9000: # skip if VX != VY
        if (curSys.reg[((opcode and 0x0F00) shr 8)]) != (curSys.reg[((opcode and 0x00F0) shr 4)]):
            curSys.pc += 2
    of 0xA000: # set I to NNN
        curSys.I = opcode and 0xFFF
    of 0xB000: # jump to NNN + V0
        jump = true
        curSys.pc = (opcode and 0x0FFF) + curSys.reg[0]
    of 0xC000: # set VX to rand + NNN
        curSys.reg[((opcode and 0x0F00) shr 8)] = rand(255).byte and (opcode and 0x00FF).byte
    of 0xD000: # Draw sprite
        let height = opcode and 0x000F
        let VX = (curSys.reg[((opcode and 0x0F00) shr 8)])
        let VY = (curSys.reg[((opcode and 0x00F0) shr 4)])
        curSys.reg[0x0F] = 0
        for i in 0..<height.int:
            for j in 0..<8:
                if ((curSys.mem[curSys.I + i.uint16]) and (0x80 shr j).byte) != 0:
                    let index = (VX + j) mod 64 + ((VY + i) mod 32)*64
                    if curSys.pix[index] == 0xFFFFFFFF.uint32:
                        curSys.reg[0x0F] = 1
                        curSys.pix[index] = 0xFF000000.uint32
                    else:
                        curSys.pix[index] = 0xFFFFFFFF.uint32

                    curSys.draw = true
    of 0xE000:
        let NNN = (opcode and 0x00FF).byte
        case NNN
        of 0x009E: # skip if key == VX
            if getKeyboardState(nil)[keyMap[curSys.reg[((opcode and 0x0F00) shr 8)]]] != 0:
                curSys.pc += 2
        of 0x00A1: # skip if key != VX
            if getKeyboardState(nil)[keyMap[curSys.reg[((opcode and 0x0F00) shr 8)]]] == 0:
                curSys.pc += 2
        else:
            echo("unknown opcode 0d" & $opcode.toHex)
    of 0xF000:
        case opcode and 0x00FF
        of 0x0007: # VX = delay timer
            curSys.reg[((opcode and 0x0F00) shr 8)] = curSys.delT
        of 0x000A: # await key press then store in VX
            curSys.pc -= 2
            for i in 0..<16:
                if getKeyboardState(nil)[keyMap[i]] != 0:
                    curSys.reg[((opcode and 0x0F00) shr 8)] = i.byte
                    curSys.pc += 2
                    break
        of 0x0015: # delay timer = VX
            curSys.delT = curSys.reg[((opcode and 0x0F00) shr 8)]
        of 0x0018: # sound timer = VX
            curSys.delS = curSys.reg[((opcode and 0x0F00) shr 8)]
        of 0x001E: # I += VX
            curSys.I += curSys.reg[((opcode and 0x0F00) shr 8)]
        of 0x0029: # Sets I to the location of the sprite for the character in VX. Characters 0-F (in hexadecimal) are represented by a 4x5 font.
            curSys.I = (curSys.reg[((opcode and 0x0F00) shr 8)]).uint16 * 5
        of 0x0033: # store BCD of VX
            var VX = $((curSys.reg[((opcode and 0x0F00) shr 8)]).int)
            VX &= "00"
            curSys.mem[curSys.I] = parseInt(($VX)[0..0]).byte
            curSys.mem[curSys.I + 1] = parseInt(($VX)[1..1]).byte
            curSys.mem[curSys.I + 2] = parseInt(($VX)[2..2]).byte
        of 0x0055: # Stores V0 to VX (including VX) in memory starting at address I
            let X = (opcode and 0x0F00) shr 8
            for i in 0..curSys.reg[X].int:
                curSys.mem[curSys.I + i.uint8] = curSys.reg[i]
            curSys.I += X+1
        of 0x0065: # Fills V0 to VX (including VX) with values from memory starting at address I.
            let X = (opcode and 0x0F00) shr 8
            for i in 0..curSys.reg[X].int:
                 curSys.reg[i] = curSys.mem[curSys.I + i.uint8]
        else:
            echo("Unknown opcode 0x" & $opcode.toHex)
    else:
        echo("Unknown opcode 0x" & $opcode.toHex)

    if not jump:
        curSys.pc += 2

    if curSys.delT > 0.byte:
        curSys.delT -= 1
    if curSys.delS == 1.byte:
        echo("BOOP")
        curSys.delS -= 1


proc startMachine() =
    var ourSys = initSystem()
    loadGame("pong.bin", ourSys)

    var display: Display
    displayInit(display)

    var stTick: uint32
    var speed: uint32
    var event: Event
    var done = false

    while not done:
        stTick = getTicks()

        emulate(ourSys)
        if ourSys.draw:
            displayDraw(display, ourSys.pix)
            ourSys.draw = false

        speed = getTicks() - stTick
        if speed.float < 1000/60:
            delay((1000/60).uint32 - speed)

        while pollEvent(addr event) != 0:
            if event.kind == QUIT:
                done = true

    displayClean(display)

when isMainModule:
    startMachine()