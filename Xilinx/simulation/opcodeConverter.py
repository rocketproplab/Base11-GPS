import json

def findOp(data):
    for element in data:
        if element['name'] == 'op':
            return element

def isOp(op):
    return op & 0x8000 > 0

def isBasicOp(op):
    soFar = isOp(op)
    return soFar and (op < 0x9F00)

def convertBasicOp(op):
    if not (op & 0xFF == 0):
        print("Error processing " + hex(op))
        return "?" + hex(op)
    opMap = ["nop", "dup", "swap", "swap16", "over", "drop", "rot", "addi",
        "add", "sub", "mult", "and", "or", "xor", "not", "8F?", "shl64", "shl",
        "shr", "rdBit", "fetch16", "stroe16", "96?", "97?", "98?", "99?", "9A?",
        "9B?", "r", "r_from", "to_r"]
    opIdx = op - 0x8000
    opIdx = opIdx >> 8
    return opMap[opIdx]

def isBranch(op):
    return op & 0xF000 == 0xA000 or op & 0xF000 == 0xB000

def convertBranch(op):
    location = op & 0xFF8
    location = location >> 1
    opMap = ["call", "BR", "BR.Z", "BR.NZ"]
    opMapIdx = ((op & 0x1000) >> 11) + (op & 0x1)
    return opMap[opMapIdx] + "_" + format(location, 'x') + "/" + str(location)

def isRdReg(op):
    return op & 0xF000 == 0xC000

def convertRdReg(op):
    regIdx = op & 0xFF
    regLoc = "?" + hex(op)
    if regIdx == 0 :
        regLoc = "CHN_IQ"
    elif regIdx == 0b1 :
        regLoc = "SRQ"
    elif regIdx == 0b10 :
        regLoc = "SNPSHT"
    elif regIdx == 0b100:
        regLoc = "JTAG_RX"
    elif regIdx == 0b1000:
        regLoc = "JOY"
    return "rdReg_" + regLoc

def isWrEvt(op):
    return op & 0xF000 == 0xE000

def convertWrEvt(op):
    regIdx = op & 0xFF
    regLoc = "?"  + hex(op)
    if regIdx == 0 :
        regLoc = "JTAG_RST"
    elif regIdx == 0b1 :
        regLoc = "JTAG_RDY"
    elif regIdx == 0b10 :
        regLoc = "SMPL_R"
    elif regIdx == 0b100:
        regLoc = "G_SMPLS"
    elif regIdx == 0b1000:
        regLoc = "G_MEMORY"
    elif regIdx == 0b10000:
        regLoc = "G_LOG"
    elif regIdx == 0b100000:
        regLoc = "P_LOG"
    elif regIdx == 0b1000000:
        regLoc = "LOG_R"
    elif regIdx == 0b10000000:
        regLoc = "SET_DAC"
    return "wrEvt_" + regLoc

def isWrReg(op):
    return op & 0xF000 == 0xD000

def convertWrReg(op):
    regIdx = op & 0xFF
    regLoc = "?"  + hex(op)
    if regIdx == 0 :
        regLoc = "JTAG_TX"
    elif regIdx == 0b1 :
        regLoc = "VCO"
    elif regIdx == 0b10 :
        regLoc = "MASK"
    elif regIdx == 0b100:
        regLoc = "CHAN"
    elif regIdx == 0b1000:
        regLoc = "CA_NCO"
    elif regIdx == 0b10000:
        regLoc = "LO_NCO"
    elif regIdx == 0b100000:
        regLoc = "SV"
    elif regIdx == 0b1000000:
        regLoc = "PAUSE"
    elif regIdx == 0b10000000:
        regLoc = "LCD"
    return "wrEvt_" + regLoc

def convertOp(op):
    opCode = int(op)
    opConvert = "?" + hex(opCode)
    if not isOp(opCode) :
        opConvert = "push_" + str(opCode)
    elif isBasicOp(opCode) :
        opConvert = convertBasicOp(opCode)
    elif isBranch(opCode):
        opConvert = convertBranch(opCode)
    elif isRdReg(opCode):
        opConvert = convertRdReg(opCode)
    elif isWrEvt(opCode):
        opConvert = convertWrEvt(opCode)
    elif isWrReg(opCode):
        opConvert = convertWrReg(opCode)
    return opConvert
newOutput = ""
with open("wavedrom.json", "rd") as f:
    data = json.load(f)
    opCodes = findOp(data['signal'])
    opString = ""
    for op in opCodes['data'].split(' '):
        opString = opString + convertOp(op) + " "
    opCodes['data'] = opString
    newOutput = json.dumps(data, indent=4)

with open("wavedromp.json", "wt") as out:
    out.write(newOutput)
