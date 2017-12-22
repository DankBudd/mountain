function FindModifier(unit, modifier) {
    for (var i = 0; i < Entities.GetNumBuffs(unit); i++) {
        if (Buffs.GetName(unit, Entities.GetBuff(unit, i)) == modifier){
            return Entities.GetBuff(unit, i);
        }
    }
}

function HasModifier(unit, modifier) {
    return !!FindModifier(unit, modifier);
}

function GetStackCount(unit, modifier) {
    var m = FindModifier(unit, modifier);
    return m ? Buffs.GetStackCount(unit, m) : 0;
}

function GetRemainingModifierTime(unit, modifier) {
    var m = FindModifier(unit, modifier);
    return m ? Buffs.GetRemainingTime(unit, m) : 0;
}

function GetModifierDuration(unit, modifier) {
    var m = FindModifier(unit, modifier);
    return m ? Buffs.GetDuration(unit, m) : 0;
}

function GetModifierCount(unit, modifier) {
    for (var i = 0, j = 0; i < Entities.GetNumBuffs(unit); i++) {
        if (Buffs.GetName(unit, Entities.GetBuff(unit, i)) == modifier){
            j++;
        }
    }

    return j;
}