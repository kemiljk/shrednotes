//
//  Tricks.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//
//  Note: this file used to be one ~340-line function with 257 mutually
//  referential `let` bindings and a 257-element return-array literal.
//  Swift's type checker took ~3-4s of compile time on it.  It is now
//  split into per-category builders that each compile fast in isolation.
//

import Foundation
import SwiftUI

// MARK: - Helpers

@inline(__always)
private func pre(_ tricks: Trick...) -> [Prerequisite] {
    [Prerequisite(prerequisiteTricks: tricks)]
}

@inline(__always)
private func dep(_ tricks: Trick...) -> [DependentTricks] {
    [DependentTricks(dependentTricks: tricks)]
}

@inline(__always)
private func mk(_ name: String, _ difficulty: Int, _ type: TrickType, _ prereqs: [Prerequisite] = []) -> Trick {
    Trick(name: name, difficulty: difficulty, type: type, prerequisites: prereqs)
}

// MARK: - Category aggregates

/// Strongly-typed bundle of basic tricks so other categories can reference
/// them by name without searching a dictionary.
private struct BasicTricks {
    let ollie: Trick, fs180: Trick, bs180: Trick, kickturn: Trick, nollie: Trick
    let fakieOllie: Trick, ticTac: Trick, bs360: Trick, fs360: Trick
    let bsCaballerial: Trick, fsCaballerial: Trick, bsHalfCab: Trick, fsHalfCab: Trick
    let ollieNorth: Trick, ollieSouth: Trick, powerslide: Trick
    let switchBs180: Trick, switchBs360: Trick, switchFs180: Trick, switchFs360: Trick
    let switchOllie: Trick

    var all: [Trick] {
        [ollie, fs180, bs180, kickturn, nollie, fakieOllie, ticTac,
         bs360, fs360, bsCaballerial, fsCaballerial, bsHalfCab, fsHalfCab,
         ollieNorth, ollieSouth, powerslide, switchBs180, switchBs360,
         switchFs180, switchFs360, switchOllie]
    }
}

private struct FlipTricks {
    let kickflip: Trick, heelflip: Trick, popShuvit: Trick, fsPopShuvit: Trick
    let varialKickflip: Trick, varialHeelflip: Trick
    let fsKickflip: Trick, bsKickflip: Trick, fsHeelflip: Trick, bsHeelflip: Trick
    let nollieBs180: Trick, nollieFs180: Trick
    let fsBigspin: Trick, bsBigspin: Trick, treFlip: Trick, hardflip: Trick
    let laserFlip: Trick, bigspin: Trick, bigflip: Trick, biggerflip: Trick
    let impossible: Trick, inwardHeelflip: Trick
    let casperFlip: Trick, halfCasperFlip: Trick, pressureFlip: Trick
    let hospitalFlip: Trick, doubleKickflip: Trick, doubleHeelflip: Trick
    let dragonFlip: Trick, dolphinFlip: Trick, ghettoBird: Trick
    let nollieShuvit: Trick, fsShuvit: Trick, nollieFsShuvit: Trick
    let shuvit360: Trick, fs360Shuvit: Trick, fakie360Shuvit: Trick, biggerspin: Trick
    let nollie360Hardflip: Trick, nollie360PopShuvit: Trick
    let nollieBsBigspin: Trick, nollieFsBigspin: Trick, nollieHardflip: Trick
    let nollieHeelflip: Trick, nollieImpossible: Trick, nollieInwardHeelflip: Trick
    let nollieKickflip: Trick, nollieLaserFlip: Trick
    let nollie360Flip: Trick, nollieVarialHeelflip: Trick, nollieVarialKickflip: Trick

    var all: [Trick] {
        [kickflip, heelflip, popShuvit, fsPopShuvit, varialKickflip, varialHeelflip,
         fsKickflip, bsKickflip, fsHeelflip, bsHeelflip, nollieBs180, nollieFs180,
         nollie360Flip, nollie360Hardflip, nollie360PopShuvit, nollieBsBigspin,
         nollieFsBigspin, nollieHardflip, nollieHeelflip, nollieImpossible,
         nollieInwardHeelflip, nollieKickflip, nollieLaserFlip, nollieVarialHeelflip,
         nollieVarialKickflip, fsBigspin, bsBigspin, treFlip, hardflip, laserFlip,
         bigspin, bigflip, biggerflip, fsShuvit, nollieShuvit, nollieFsShuvit,
         casperFlip, halfCasperFlip, pressureFlip, hospitalFlip, doubleKickflip,
         doubleHeelflip, dragonFlip, ghettoBird, shuvit360, fs360Shuvit,
         fakie360Shuvit, biggerspin, dolphinFlip]
    }
}

private struct GrindAndSlideTricks {
    let backside50_50: Trick, frontside50_50: Trick
    let backside5_0: Trick, frontside5_0: Trick
    let backsideCrooked: Trick, frontsideCrooked: Trick
    let backsideFeeble: Trick, frontsideFeeble: Trick
    let backsideLipslide: Trick, frontsideLipslide: Trick
    let backsideNosegrind: Trick, frontsideNosegrind: Trick
    let backsideNoseslide: Trick, frontsideNoseslide: Trick
    let backsideOvercrook: Trick, frontsideOvercrook: Trick
    let backsideSalad: Trick, frontsideSalad: Trick
    let backsideSmith: Trick, frontsideSmith: Trick
    let backsideSuski: Trick, frontsideSuski: Trick
    let backsideTailslide: Trick, frontsideTailslide: Trick
    let backsideBluntslide: Trick, frontsideBluntslide: Trick
    let backsideNosebluntSlide: Trick, frontsideNosebluntSlide: Trick
    let backsideBoardslide: Trick, frontsideBoardslide: Trick
    let backsideHurricaneStall: Trick, frontsideHurricaneStall: Trick
    let willyGrind: Trick, hurricaneGrind: Trick, darkslide: Trick

    var all: [Trick] {
        [backside50_50, frontside50_50, backside5_0, frontside5_0,
         backsideCrooked, frontsideCrooked, backsideFeeble, frontsideFeeble,
         backsideLipslide, frontsideLipslide, backsideNosegrind, frontsideNosegrind,
         backsideNoseslide, frontsideNoseslide, backsideOvercrook, frontsideOvercrook,
         backsideSalad, frontsideSalad, backsideSmith, frontsideSmith,
         backsideSuski, frontsideSuski, backsideTailslide, frontsideTailslide,
         backsideBluntslide, frontsideBluntslide, backsideNosebluntSlide,
         frontsideNosebluntSlide, backsideBoardslide, frontsideBoardslide,
         backsideHurricaneStall, frontsideHurricaneStall, willyGrind, hurricaneGrind,
         darkslide]
    }
}

// MARK: - Builders

private func makeBasicTricks() -> BasicTricks {
    let ollie       = mk("Ollie",      1, .basic)
    let kickturn    = mk("Kickturn",   1, .basic)
    let ticTac      = mk("Tic-Tac",    1, .basic)
    let fs180       = mk("FS 180",     2, .basic, pre(ollie))
    let bs180       = mk("BS 180",     2, .basic, pre(ollie))
    let nollie      = mk("Nollie",     2, .basic, pre(ollie))
    let fakieOllie  = mk("Fakie Ollie", 2, .basic, pre(ollie))
    let bs360       = mk("BS 360",     3, .basic, pre(bs180))
    let fs360       = mk("FS 360",     3, .basic, pre(fs180))
    let bsCaballerial = mk("BS Caballerial", 4, .basic, pre(bs360))
    let fsCaballerial = mk("FS Caballerial", 4, .basic, pre(fs360))
    let bsHalfCab   = mk("BS Half Cab", 2, .basic, pre(bs180))
    let fsHalfCab   = mk("FS Half Cab", 2, .basic, pre(fs180))
    let ollieNorth  = mk("Ollie North", 2, .basic, pre(ollie))
    let ollieSouth  = mk("Ollie South", 2, .basic, pre(ollie))
    let powerslide  = mk("Powerslide",  2, .basic, pre(ollie))
    let switchBs180 = mk("Switch BS 180", 2, .basic, pre(bs180))
    let switchBs360 = mk("Switch BS 360", 3, .basic, pre(bs360))
    let switchFs180 = mk("Switch FS 180", 2, .basic, pre(fs180))
    let switchFs360 = mk("Switch FS 360", 3, .basic, pre(fs360))
    let switchOllie = mk("Switch Ollie", 2, .basic, pre(ollie))

    return BasicTricks(
        ollie: ollie, fs180: fs180, bs180: bs180, kickturn: kickturn, nollie: nollie,
        fakieOllie: fakieOllie, ticTac: ticTac, bs360: bs360, fs360: fs360,
        bsCaballerial: bsCaballerial, fsCaballerial: fsCaballerial,
        bsHalfCab: bsHalfCab, fsHalfCab: fsHalfCab,
        ollieNorth: ollieNorth, ollieSouth: ollieSouth, powerslide: powerslide,
        switchBs180: switchBs180, switchBs360: switchBs360,
        switchFs180: switchFs180, switchFs360: switchFs360, switchOllie: switchOllie
    )
}

private func makeFlipTricks(basic b: BasicTricks) -> FlipTricks {
    let kickflip   = mk("Kickflip",       3, .flip,   pre(b.ollie))
    let heelflip   = mk("Heelflip",       3, .flip,   pre(b.ollie))
    let popShuvit  = mk("Pop Shove It",   3, .shuvit)
    let fsPopShuvit = mk("FS Pop Shove It", 3, .shuvit)
    let varialKickflip = mk("Varial Kickflip", 4, .flip, pre(kickflip, popShuvit))
    let varialHeelflip = mk("Varial Heelflip", 4, .flip, pre(heelflip, fsPopShuvit))
    let fsKickflip = mk("FS 180 Kickflip", 4, .flip, pre(kickflip, b.fs180))
    let bsKickflip = mk("BS 180 Kickflip", 4, .flip, pre(kickflip, b.bs180))
    let fsHeelflip = mk("FS 180 Heelflip", 4, .flip, pre(heelflip, b.fs180))
    let bsHeelflip = mk("BS 180 Heelflip", 4, .flip, pre(heelflip, b.bs180))
    let nollieBs180 = mk("Nollie BS 180", 3, .flip, pre(b.nollie, b.bs180))
    let nollieFs180 = mk("Nollie FS 180", 3, .flip, pre(b.nollie, b.fs180))
    let fsBigspin  = mk("FS Bigspin",     5, .shuvit, pre(fsPopShuvit, b.fs180))
    let bsBigspin  = mk("BS Bigspin",     5, .shuvit, pre(popShuvit, b.bs180))
    let treFlip    = mk("Tre Flip",       5, .flip,   pre(kickflip, popShuvit, bsBigspin))
    let hardflip   = mk("Hardflip",       5, .flip,   pre(kickflip, heelflip, fsPopShuvit))
    let laserFlip  = mk("Laser Flip",     6, .flip,   pre(fsBigspin, kickflip, fsPopShuvit, heelflip))
    let bigspin    = mk("Bigspin",        4, .shuvit, pre(popShuvit, b.bs180))
    let bigflip    = mk("Bigflip",        5, .flip,   pre(bigspin, kickflip))
    let biggerflip = mk("Biggerflip",     6, .flip,   pre(bigflip))
    let impossible = mk("Impossible",     6, .flip)
    let inwardHeelflip = mk("Inward Heelflip", 3, .flip)
    let casperFlip = mk("Casper Flip",    5, .flip, pre(kickflip))
    let halfCasperFlip = mk("Half Casper Flip", 4, .flip, pre(kickflip))
    let pressureFlip = mk("Pressure Flip", 4, .flip, pre(b.ollie))
    let hospitalFlip = mk("Hospital Flip", 4, .flip, pre(kickflip))
    let doubleKickflip = mk("Double Kickflip", 6, .flip, pre(kickflip))
    let doubleHeelflip = mk("Double Heelflip", 6, .flip, pre(heelflip))
    let dragonFlip = mk("Dragon Flip", 6, .flip, pre(kickflip, popShuvit))
    let dolphinFlip = mk("Dolphin Flip", 6, .flip, pre(kickflip, popShuvit))
    let ghettoBird = mk("Ghetto Bird", 5, .flip, pre(b.nollie, b.bs180))
    let nollieShuvit = mk("Nollie Shove It", 2, .shuvit)
    let fsShuvit = mk("Nollie FS Shove It", 2, .shuvit)
    let nollieFsShuvit = mk("FS Shove It", 2, .shuvit)
    let shuvit360 = mk("360 Shove It", 4, .shuvit, pre(popShuvit))
    let fs360Shuvit = mk("FS 360 Shove It", 4, .shuvit, pre(fsPopShuvit))
    let fakie360Shuvit = mk("Fakie 360 Shove It", 4, .shuvit, pre(b.fakieOllie, popShuvit))
    let biggerspin = mk("Biggerspin", 6, .shuvit, pre(bsBigspin, b.bs360))
    let nollie360Flip = mk("Nollie 360 Flip", 5, .flip, pre(b.nollie, kickflip, popShuvit))
    let nollieVarialHeelflip = mk("Nollie Varial Heelflip", 4, .flip, pre(b.nollie, varialHeelflip))
    let nollieVarialKickflip = mk("Nollie Varial Kickflip", 4, .flip, pre(b.nollie, varialKickflip))
    let nollie360Hardflip = mk("Nollie 360 Hardflip", 5, .flip, pre(b.nollie, kickflip, hardflip))
    let nollie360PopShuvit = mk("Nollie 360 Pop Shove It", 4, .shuvit, pre(b.nollie, popShuvit))
    let nollieBsBigspin = mk("Nollie BS Bigspin", 4, .shuvit, pre(b.nollie, bsBigspin))
    let nollieFsBigspin = mk("Nollie FS Bigspin", 4, .shuvit, pre(b.nollie, fsBigspin))
    let nollieHardflip = mk("Nollie Hardflip", 5, .flip, pre(b.nollie, hardflip))
    let nollieHeelflip = mk("Nollie Heelflip", 3, .flip, pre(b.nollie, heelflip))
    let nollieImpossible = mk("Nollie Impossible", 5, .flip, pre(b.nollie, impossible))
    let nollieInwardHeelflip = mk("Nollie Inward Heelflip", 4, .flip, pre(b.nollie, inwardHeelflip))
    let nollieKickflip = mk("Nollie Kickflip", 3, .flip, pre(b.nollie, kickflip))
    let nollieLaserFlip = mk("Nollie Laser Flip", 6, .flip, pre(b.nollie, laserFlip))

    return FlipTricks(
        kickflip: kickflip, heelflip: heelflip, popShuvit: popShuvit, fsPopShuvit: fsPopShuvit,
        varialKickflip: varialKickflip, varialHeelflip: varialHeelflip,
        fsKickflip: fsKickflip, bsKickflip: bsKickflip, fsHeelflip: fsHeelflip, bsHeelflip: bsHeelflip,
        nollieBs180: nollieBs180, nollieFs180: nollieFs180,
        fsBigspin: fsBigspin, bsBigspin: bsBigspin, treFlip: treFlip, hardflip: hardflip,
        laserFlip: laserFlip, bigspin: bigspin, bigflip: bigflip, biggerflip: biggerflip,
        impossible: impossible, inwardHeelflip: inwardHeelflip,
        casperFlip: casperFlip, halfCasperFlip: halfCasperFlip, pressureFlip: pressureFlip,
        hospitalFlip: hospitalFlip, doubleKickflip: doubleKickflip, doubleHeelflip: doubleHeelflip,
        dragonFlip: dragonFlip, dolphinFlip: dolphinFlip, ghettoBird: ghettoBird,
        nollieShuvit: nollieShuvit, fsShuvit: fsShuvit, nollieFsShuvit: nollieFsShuvit,
        shuvit360: shuvit360, fs360Shuvit: fs360Shuvit, fakie360Shuvit: fakie360Shuvit, biggerspin: biggerspin,
        nollie360Hardflip: nollie360Hardflip, nollie360PopShuvit: nollie360PopShuvit,
        nollieBsBigspin: nollieBsBigspin, nollieFsBigspin: nollieFsBigspin, nollieHardflip: nollieHardflip,
        nollieHeelflip: nollieHeelflip, nollieImpossible: nollieImpossible, nollieInwardHeelflip: nollieInwardHeelflip,
        nollieKickflip: nollieKickflip, nollieLaserFlip: nollieLaserFlip,
        nollie360Flip: nollie360Flip, nollieVarialHeelflip: nollieVarialHeelflip, nollieVarialKickflip: nollieVarialKickflip
    )
}

private func makeGrindAndSlideTricks(basic b: BasicTricks) -> GrindAndSlideTricks {
    let backside50_50  = mk("BS 50-50", 3, .grind)
    let frontside50_50 = mk("FS 50-50", 3, .grind)
    let backside5_0    = mk("BS 5-0",   4, .grind, pre(backside50_50))
    let frontside5_0   = mk("FS 5-0",   4, .grind, pre(frontside50_50))
    let backsideCrooked  = mk("BS Crooked", 4, .grind)
    let frontsideCrooked = mk("FS Crooked", 4, .grind)
    let backsideFeeble  = mk("BS Feeble", 4, .grind)
    let frontsideFeeble = mk("FS Feeble", 4, .grind)
    let backsideLipslide  = mk("BS Lipslide", 4, .slide)
    let frontsideLipslide = mk("FS Lipslide", 4, .slide)
    let backsideNosegrind  = mk("BS Nosegrind", 4, .grind)
    let frontsideNosegrind = mk("FS Nosegrind", 4, .grind)
    let backsideNoseslide  = mk("BS Noseslide", 3, .slide)
    let frontsideNoseslide = mk("FS Noseslide", 3, .slide)
    let backsideOvercrook  = mk("BS Overcrook", 4, .grind)
    let frontsideOvercrook = mk("FS Overcrook", 4, .grind)
    let backsideSalad  = mk("BS Salad", 4, .grind)
    let frontsideSalad = mk("FS Salad", 4, .grind)
    let backsideSmith  = mk("BS Smith", 4, .grind)
    let frontsideSmith = mk("FS Smith", 4, .grind)
    let backsideSuski  = mk("BS Suski", 4, .grind, pre(backside5_0, backsideSalad))
    let frontsideSuski = mk("FS Suski", 4, .grind, pre(frontside5_0, frontsideSalad))
    let willyGrind     = mk("Willy Grind", 5, .grind, pre(frontside5_0))
    let hurricaneGrind = mk("Hurricane Grind", 5, .grind, pre(backsideCrooked, b.bs180))
    let backsideTailslide  = mk("BS Tailslide", 4, .slide)
    let frontsideTailslide = mk("FS Tailslide", 4, .slide)
    let backsideBluntslide = mk("BS Bluntslide", 5, .slide, pre(backsideTailslide))
    let frontsideBluntslide = mk("FS Bluntslide", 5, .slide, pre(frontsideTailslide))
    let backsideNosebluntSlide  = mk("BS Noseblunt Slide", 5, .slide, pre(backsideNoseslide))
    let frontsideNosebluntSlide = mk("FS Noseblunt Slide", 5, .slide, pre(frontsideNoseslide))
    let backsideBoardslide  = mk("BS Boardslide", 3, .slide)
    let frontsideBoardslide = mk("FS Boardslide", 3, .slide)
    let backsideHurricaneStall  = mk("BS Hurricane Stall", 4, .transition)
    let frontsideHurricaneStall = mk("FS Hurricane Stall", 4, .transition)
    let darkslide = mk("Darkslide", 6, .slide, pre(backsideBoardslide))

    return GrindAndSlideTricks(
        backside50_50: backside50_50, frontside50_50: frontside50_50,
        backside5_0: backside5_0, frontside5_0: frontside5_0,
        backsideCrooked: backsideCrooked, frontsideCrooked: frontsideCrooked,
        backsideFeeble: backsideFeeble, frontsideFeeble: frontsideFeeble,
        backsideLipslide: backsideLipslide, frontsideLipslide: frontsideLipslide,
        backsideNosegrind: backsideNosegrind, frontsideNosegrind: frontsideNosegrind,
        backsideNoseslide: backsideNoseslide, frontsideNoseslide: frontsideNoseslide,
        backsideOvercrook: backsideOvercrook, frontsideOvercrook: frontsideOvercrook,
        backsideSalad: backsideSalad, frontsideSalad: frontsideSalad,
        backsideSmith: backsideSmith, frontsideSmith: frontsideSmith,
        backsideSuski: backsideSuski, frontsideSuski: frontsideSuski,
        backsideTailslide: backsideTailslide, frontsideTailslide: frontsideTailslide,
        backsideBluntslide: backsideBluntslide, frontsideBluntslide: frontsideBluntslide,
        backsideNosebluntSlide: backsideNosebluntSlide, frontsideNosebluntSlide: frontsideNosebluntSlide,
        backsideBoardslide: backsideBoardslide, frontsideBoardslide: frontsideBoardslide,
        backsideHurricaneStall: backsideHurricaneStall, frontsideHurricaneStall: frontsideHurricaneStall,
        willyGrind: willyGrind, hurricaneGrind: hurricaneGrind, darkslide: darkslide
    )
}

private func makeAirAndTransitionTricks(grinds g: GrindAndSlideTricks) -> [Trick] {
    let air540 = mk("540", 5, .air)
    let air720 = mk("720", 6, .air, pre(air540))
    let air900 = mk("900", 7, .air, pre(air720))

    let airwalk = mk("Airwalk", 4, .air)
    let axleDropIn = mk("Axle Drop-In", 3, .transition, pre(g.frontside50_50))
    let backsideAxleStall = mk("BS Axle Stall", 3, .transition, pre(g.backside50_50))
    let backsideCrookedStall = mk("BS Crooked Stall", 4, .transition, pre(g.backsideCrooked))
    let backsideDisaster = mk("BS Disaster", 4, .transition, pre(g.backsideBoardslide))
    let backsideFeebleStall = mk("BS Feeble Stall", 4, .transition, pre(g.backsideFeeble))
    let backsidePivotStall = mk("BS Pivot Stall", 3, .transition, pre(g.backside5_0))
    let backsideRockNRoll = mk("BS Rock 'n' roll", 3, .transition, pre(g.frontsideBoardslide))
    let backsideSmithStall = mk("BS Smith Stall", 4, .transition, pre(g.backsideSmith))
    let backsideTailStall = mk("BS Tail Stall", 4, .transition, pre(g.backsideTailslide))
    let benihana = mk("Benihana", 4, .air)
    let bluntStall180Out = mk("Blunt Stall 180 Out", 5, .transition, pre(g.frontsideBluntslide))
    let bluntStallPullBack = mk("Blunt Stall Pull Back", 4, .transition, pre(g.frontsideBluntslide))
    let bluntStallToFakie = mk("Blunt Stall to Fakie", 4, .transition, pre(g.frontsideBluntslide))
    let bodyJar = mk("Body Jar", 4, .air)
    let cannonball = mk("Cannonball", 3, .air)
    let christAir = mk("Christ Air", 5, .air)
    let crailGrab = mk("Crail Grab", 3, .air)
    let creeper = mk("Creeper", 3, .air)
    let crossbone = mk("Crossbone", 4, .air)
    let delmarIndy = mk("Delmar Indy", 4, .air)
    let doubleGrab = mk("Double Grab", 4, .air)
    let dropIn = mk("Drop-In", 2, .transition)
    let fakieNosebluntStall = mk("Fakie Noseblunt Stall", 5, .transition, pre(g.frontsideNosebluntSlide))
    let fakieRock = mk("Fakie Rock", 3, .transition, pre(g.frontsideBoardslide))
    let fakieTailStall = mk("Fakie Tail Stall", 4, .transition)
    let frigidAir = mk("Frigid Air", 4, .air)
    let frontsideAir = mk("FS Air", 3, .air)
    let frontsideAxleStall = mk("FS Axle Stall", 3, .transition, pre(g.frontside50_50))
    let frontsideCrookedStall = mk("FS Crooked Stall", 4, .transition, pre(g.frontsideCrooked))
    let frontsideDisaster = mk("FS Disaster", 4, .transition, pre(g.frontsideBoardslide))
    let frontsideFeebleStall = mk("FS Feeble Stall", 4, .transition, pre(g.frontsideFeeble))
    let frontsideNosePick = mk("FS Nose Pick", 4, .transition, pre(g.frontsideNosegrind))
    let frontsideNosebluntStall = mk("FS Noseblunt Stall", 5, .transition, pre(g.frontsideNosebluntSlide))
    let frontsidePivotStall = mk("FS Pivot Stall", 3, .transition, pre(g.frontside50_50))
    let frontsideRockNRoll = mk("FS Rock 'n' roll", 3, .transition, pre(g.frontsideBoardslide))
    let frontsideSmithStall = mk("FS Smith Stall", 4, .transition, pre(g.frontsideSmith))
    let frontsideSugarcaneStall = mk("FS Sugarcane Stall", 5, .transition)
    let frontsideSweeper = mk("FS Sweeper", 3, .transition)
    let frontsideTailStall = mk("FS Tail Stall", 4, .transition, pre(g.frontsideTailslide))
    let grosmanGrab = mk("Grosman Grab", 4, .air)
    let helipop = mk("Helipop", 5, .air)
    let indy = mk("Indy", 3, .air)
    let indyGrab = mk("Indy Grab", 3, .air)
    let invert = mk("Invert", 4, .air)
    let japanAir = mk("Japan Air", 4, .air)
    let judoAir = mk("Judo Air", 4, .air)
    let lienAir = mk("Lien Air", 4, .air)
    let madonna = mk("Madonna", 5, .air)
    let mcTwist = mk("McTwist", 5, .air)
    let melancholyGrab = mk("Melancholy Grab", 4, .air)
    let melon = mk("Melon", 3, .air)
    let methodAir = mk("Method Air", 4, .air)
    let muteAir = mk("Mute Air", 3, .air)
    let noseGrab = mk("Nose Grab", 3, .air)
    let nosePick = mk("Nose Pick", 4, .transition, pre(g.frontsideNosegrind))
    let noseStall = mk("Nose Stall", 3, .transition, pre(g.frontsideNoseslide))
    let nosebone = mk("Nosebone", 4, .air)
    let nuclearGrab = mk("Nuclear Grab", 4, .air)
    let riverdance = mk("Riverdance", 4, .air)
    let roastbeefGrab = mk("Roastbeef Grab", 3, .air)
    let rockToFakie = mk("Rock to Fakie", 3, .transition, pre(g.frontsideBoardslide))
    let rocketAir = mk("Rocket Air", 4, .air)
    let sacktap = mk("Sacktap", 4, .air)
    let salFlip = mk("Sal Flip", 5, .air)
    let saranWrap = mk("Saran Wrap", 4, .air)
    let seatbeltGrab = mk("Seatbelt Grab", 3, .air)
    let slobAir = mk("Slob Air", 3, .air)
    let stalefishGrab = mk("Stalefish Grab", 3, .air)
    let stallfish = mk("Stallfish", 4, .air)
    let stiffy = mk("Stiffy", 4, .air)
    let supermanGrab = mk("Superman Grab", 5, .air)
    let tailGrab = mk("Tail Grab", 3, .air)
    let tailbone = mk("Tailbone", 4, .air)
    let tuckKnee = mk("Tuck Knee", 4, .air)
    let varial = mk("Varial", 4, .air)

    // Wire up multi-stage air dependencies
    air540.dependentTricks = dep(air720)
    air720.dependentTricks = dep(air900)

    return [
        air540, air720, air900, airwalk, axleDropIn, backsideAxleStall, backsideCrookedStall,
        backsideDisaster, backsideFeebleStall, backsidePivotStall, backsideRockNRoll,
        backsideSmithStall, backsideTailStall, benihana, bluntStall180Out, bluntStallPullBack,
        bluntStallToFakie, bodyJar, cannonball, christAir, crailGrab, creeper, crossbone,
        delmarIndy, doubleGrab, dropIn, fakieNosebluntStall, fakieRock, fakieTailStall,
        frigidAir, frontsideAir, frontsideAxleStall, frontsideCrookedStall, frontsideDisaster,
        frontsideFeebleStall, frontsideNosePick, frontsideNosebluntStall, frontsidePivotStall,
        frontsideRockNRoll, frontsideSmithStall, frontsideSugarcaneStall, frontsideSweeper,
        frontsideTailStall, grosmanGrab, helipop, indy, indyGrab, invert, japanAir, judoAir,
        lienAir, madonna, mcTwist, melancholyGrab, melon, methodAir, muteAir, noseGrab,
        nosePick, noseStall, nosebone, nuclearGrab, riverdance, roastbeefGrab, rockToFakie,
        rocketAir, sacktap, salFlip, saranWrap, seatbeltGrab, slobAir, stalefishGrab,
        stallfish, stiffy, supermanGrab, tailGrab, tailbone, tuckKnee, varial
    ]
}

private func makeFootplantTricks() -> [Trick] {
    [
        mk("Bean Plant",   3, .footplant),
        mk("Egg Plant",    4, .footplant),
        mk("Fastplant",    3, .footplant),
        mk("Gymnast Plant", 4, .footplant),
        mk("Ho-Ho",        5, .footplant),
        mk("Layback Air",  4, .footplant),
        mk("Miller Flip",  5, .footplant),
        mk("Power Ollie",  3, .footplant),
        mk("Sad Plant",    4, .footplant),
        mk("Staple Gun",   4, .footplant),
        mk("Texas Plant",  4, .footplant),
        mk("Texas Two-Step", 4, .footplant)
    ]
}

private func makeBalanceTricks() -> [Trick] {
    [
        mk("Manual",            2, .balance),
        mk("Nose Manual",       3, .balance),
        mk("One Foot Manual",   3, .balance),
        mk("One Wheel Manual",  4, .balance)
    ]
}

private func makeMiscTricks() -> [Trick] {
    [
        mk("Casper",         4, .misc),
        mk("Casper Stall",   5, .misc),
        mk("No Comply",      3, .misc),
        mk("Acid Drop",      3, .misc),
        mk("Alley Oop",      3, .misc),
        mk("BS Boneless",    3, .misc),
        mk("BS Wallride",    4, .misc),
        mk("Body Varial",    2, .misc),
        mk("Boneless",       3, .misc),
        mk("Caveman",        2, .misc),
        mk("Coffin",         2, .misc),
        mk("Daffy",          3, .misc),
        mk("Firecracker",    3, .misc),
        mk("Flamingo",       4, .misc),
        mk("FS Boneless",    3, .misc),
        mk("FS Wallride",    4, .misc),
        mk("Hang Ten",       3, .misc),
        mk("Hippie Jump",    2, .misc),
        mk("Pogo",           3, .misc),
        mk("Primo Stall",    4, .misc),
        mk("Roll In",        2, .misc),
        mk("Strawberry Milkshake", 4, .misc),
        mk("Street Plant",   4, .misc),
        mk("Wallie",         3, .misc)
    ]
}

private func wireTopLevelDependents(basic b: BasicTricks, flips f: FlipTricks, grinds g: GrindAndSlideTricks) {
    b.ollie.dependentTricks      = dep(b.ollieNorth, b.ollieSouth, b.powerslide, b.switchOllie)
    b.fs180.dependentTricks      = dep(b.fs360, b.fsHalfCab, b.switchFs180)
    b.bs180.dependentTricks      = dep(b.bs360, b.bsHalfCab, b.switchBs180)
    b.nollie.dependentTricks     = dep(f.nollieBs180, f.nollieFs180)
    b.bs360.dependentTricks      = dep(b.bsCaballerial, b.switchBs360)
    b.fs360.dependentTricks      = dep(b.fsCaballerial, b.switchFs360)
    f.kickflip.dependentTricks   = dep(f.varialKickflip, f.fsKickflip, f.bsKickflip, f.treFlip)
    f.heelflip.dependentTricks   = dep(f.varialHeelflip, f.fsHeelflip, f.bsHeelflip)
    f.popShuvit.dependentTricks  = dep(f.varialKickflip, f.bsBigspin, f.treFlip)
    f.fsPopShuvit.dependentTricks = dep(f.varialHeelflip, f.fsBigspin)
    f.bigflip.dependentTricks    = dep(f.biggerflip)
    g.backside50_50.dependentTricks  = dep(g.backside5_0, g.backsideSmith, g.backsideFeeble)
    g.frontside50_50.dependentTricks = dep(g.frontside5_0, g.frontsideSmith, g.frontsideFeeble)
    g.backside5_0.dependentTricks    = dep(g.backsideSuski)
    g.frontside5_0.dependentTricks   = dep(g.frontsideSuski)
    g.backsideNoseslide.dependentTricks  = dep(g.backsideNosebluntSlide)
    g.frontsideNoseslide.dependentTricks = dep(g.frontsideNosebluntSlide)
    g.backsideTailslide.dependentTricks  = dep(g.backsideBluntslide)
    g.frontsideTailslide.dependentTricks = dep(g.frontsideBluntslide)
}

// MARK: - Public entry points

func generateTricks() -> [Trick] {
    let basic = makeBasicTricks()
    let flips = makeFlipTricks(basic: basic)
    let grinds = makeGrindAndSlideTricks(basic: basic)
    let airs = makeAirAndTransitionTricks(grinds: grinds)
    let footplant = makeFootplantTricks()
    let balance = makeBalanceTricks()
    let misc = makeMiscTricks()

    wireTopLevelDependents(basic: basic, flips: flips, grinds: grinds)

    var all: [Trick] = []
    all.reserveCapacity(basic.all.count + flips.all.count + grinds.all.count
                        + airs.count + footplant.count + balance.count + misc.count)
    all.append(contentsOf: basic.all)
    all.append(contentsOf: flips.all)
    all.append(contentsOf: grinds.all)
    all.append(contentsOf: airs)
    all.append(contentsOf: footplant)
    all.append(contentsOf: balance)
    all.append(contentsOf: misc)
    return all
}

func generateNewTricksV2() -> [Trick] {
    let ollie       = mk("Ollie",          1, .basic)
    let kickflip    = mk("Kickflip",       3, .flip,   pre(ollie))
    let heelflip    = mk("Heelflip",       3, .flip,   pre(ollie))
    let popShuvit   = mk("Pop Shove It",   3, .shuvit)
    let fsPopShuvit = mk("FS Pop Shove It", 3, .shuvit)
    let fakieOllie  = mk("Fakie Ollie",    2, .basic, pre(ollie))
    let nollie      = mk("Nollie",         2, .basic, pre(ollie))
    let bs180       = mk("BS 180",         2, .basic, pre(ollie))
    let backsideBoardslide = mk("BS Boardslide", 3, .slide)
    let backsideCrooked    = mk("BS Crooked",    4, .grind)
    let frontside5_0       = mk("FS 5-0",        4, .grind)
    let bsBigspin = mk("BS Bigspin", 5, .shuvit, pre(popShuvit))
    let bs360     = mk("BS 360",     3, .basic)

    let casperFlip       = mk("Casper Flip",       5, .flip, pre(kickflip))
    let halfCasperFlip   = mk("Half Casper Flip",  4, .flip, pre(kickflip))
    let pressureFlip     = mk("Pressure Flip",     4, .flip, pre(ollie))
    let hospitalFlip     = mk("Hospital Flip",     4, .flip, pre(kickflip))
    let doubleKickflip   = mk("Double Kickflip",   6, .flip, pre(kickflip))
    let doubleHeelflip   = mk("Double Heelflip",   6, .flip, pre(heelflip))
    let dragonFlip       = mk("Dragon Flip",       6, .flip, pre(kickflip, popShuvit))
    let ghettoBird       = mk("Ghetto Bird",       5, .flip, pre(nollie, bs180))
    let shuvit360        = mk("360 Shove It",      4, .shuvit, pre(popShuvit))
    let fs360Shuvit      = mk("FS 360 Shove It",   4, .shuvit, pre(fsPopShuvit))
    let fakie360Shuvit   = mk("Fakie 360 Shove It", 4, .shuvit, pre(fakieOllie, popShuvit))
    let biggerspin       = mk("Biggerspin",        6, .shuvit, pre(bsBigspin, bs360))
    let darkslide        = mk("Darkslide",         6, .slide,  pre(backsideBoardslide))
    let willyGrind       = mk("Willy Grind",       5, .grind,  pre(frontside5_0))
    let hurricaneGrind   = mk("Hurricane Grind",   5, .grind,  pre(backsideCrooked, bs180))
    let casper           = mk("Casper",            4, .misc)
    let casperStall      = mk("Casper Stall",      5, .misc)
    let noComply         = mk("No Comply",         3, .misc)

    return [
        casperFlip, halfCasperFlip, pressureFlip, hospitalFlip, doubleKickflip,
        doubleHeelflip, dragonFlip, ghettoBird, shuvit360, fs360Shuvit, fakie360Shuvit,
        biggerspin, darkslide, willyGrind, hurricaneGrind, casper, casperStall, noComply
    ]
}
