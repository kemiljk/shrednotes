//
//  Tricks.swift
//  Shrednotes
//
//  Created by Karl Koch on 12/11/2024.
//

import Foundation
import SwiftUI

func generateTricks() -> [Trick] {
    let ollie = Trick(name: "Ollie", difficulty: 1, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let fs180 = Trick(name: "FS 180", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [ollie])])
    let bs180 = Trick(name: "BS 180", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [ollie])])
    let kickturn = Trick(name: "Kickturn", difficulty: 1, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let nollie = Trick(name: "Nollie", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [ollie])])
    let fakieOllie = Trick(name: "Fakie Ollie", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [ollie])])
    let ticTac = Trick(name: "Tic-Tac", difficulty: 1, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let bs360 = Trick(name: "BS 360", difficulty: 3, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [bs180])])
    let fs360 = Trick(name: "FS 360", difficulty: 3, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [fs180])])
    let bsCaballerial = Trick(name: "BS Caballerial", difficulty: 4, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [bs360])])
    let fsCaballerial = Trick(name: "FS Caballerial", difficulty: 4, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [fs360])])
    let bsHalfCab = Trick(name: "BS Half Cab", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [bs180])])
    let fsHalfCab = Trick(name: "FS Half Cab", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [fs180])])
    let ollieNorth = Trick(name: "Ollie North", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [ollie])])
    let ollieSouth = Trick(name: "Ollie South", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [ollie])])
    let powerslide = Trick(name: "Powerslide", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [ollie])])
    let switchBs180 = Trick(name: "Switch BS 180", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [bs180])])
    let switchBs360 = Trick(name: "Switch BS 360", difficulty: 3, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [bs360])])
    let switchFs180 = Trick(name: "Switch FS 180", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [fs180])])
    let switchFs360 = Trick(name: "Switch FS 360", difficulty: 3, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [fs360])])
    let switchOllie = Trick(name: "Switch Ollie", difficulty: 2, type: .basic, prerequisites: [Prerequisite(prerequisiteTricks: [ollie])])

    // Flip and Shove-It Tricks
    let kickflip = Trick(name: "Kickflip", difficulty: 3, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [ollie])])
    let heelflip = Trick(name: "Heelflip", difficulty: 3, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [ollie])])
    let popShuvit = Trick(name: "Pop Shove It", difficulty: 3, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let fsPopShuvit = Trick(name: "FS Pop Shove It", difficulty: 3, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let varialKickflip = Trick(name: "Varial Kickflip", difficulty: 4, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [kickflip, popShuvit])])
    let varialHeelflip = Trick(name: "Varial Heelflip", difficulty: 4, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [heelflip, fsPopShuvit])])
    let fsKickflip = Trick(name: "FS 180 Kickflip", difficulty: 4, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [kickflip, fs180])])
    let bsKickflip = Trick(name: "BS 180 Kickflip", difficulty: 4, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [kickflip, bs180])])
    let fsHeelflip = Trick(name: "FS 180 Heelflip", difficulty: 4, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [heelflip, fs180])])
    let bsHeelflip = Trick(name: "BS 180 Heelflip", difficulty: 4, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [heelflip, bs180])])
    let nollieBs180 = Trick(name: "Nollie BS 180", difficulty: 3, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, bs180])])
    let nollieFs180 = Trick(name: "Nollie FS 180", difficulty: 3, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, fs180])])
    let nollie360Flip = Trick(name: "Nollie 360 Flip", difficulty: 5, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, kickflip, popShuvit])])
    let nollieVarialHeelflip = Trick(name: "Nollie Varial Heelflip", difficulty: 4, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, varialHeelflip])])
    let nollieVarialKickflip = Trick(name: "Nollie Varial Kickflip", difficulty: 4, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, varialKickflip])])
    let fsBigspin = Trick(name: "FS Bigspin", difficulty: 5, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [fsPopShuvit, fs180])])
    let bsBigspin = Trick(name: "BS Bigspin", difficulty: 5, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [popShuvit, bs180])])
    let treFlip = Trick(name: "Tre Flip", difficulty: 5, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [kickflip, popShuvit, bsBigspin])])
    let hardflip = Trick(name: "Hardflip", difficulty: 5, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [kickflip, heelflip, fsPopShuvit])])
    let laserFlip = Trick(name: "Laser Flip", difficulty: 6, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [fsBigspin, kickflip, fsPopShuvit, heelflip])])
    let bigspin = Trick(name: "Bigspin", difficulty: 4, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [popShuvit, bs180])])
    let bigflip = Trick(name: "Bigflip", difficulty: 5, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [bigspin, kickflip])])
    let biggerflip = Trick(name: "Biggerflip", difficulty: 6, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [bigflip])])
    let impossible = Trick(name: "Impossible", difficulty: 6, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let inwardHeelflip = Trick(name: "Inward Heelflip", difficulty: 3, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let shuvit = Trick(name: "Shuvit", difficulty: 2, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let nollieShuvit = Trick(name: "Nollie Shove It", difficulty: 2, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let fsShuvit = Trick(name: "Nollie FS Shove It", difficulty: 2, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let nollieFsShuvit = Trick(name: "FS Shove It", difficulty: 2, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let nollie360Hardflip = Trick(name: "Nollie 360 Hardflip", difficulty: 5, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, kickflip, hardflip])])
    let nollie360PopShuvit = Trick(name: "Nollie 360 Pop Shove It", difficulty: 4, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, popShuvit])])
    let nollieBsBigspin = Trick(name: "Nollie BS Bigspin", difficulty: 4, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, bsBigspin])])
    let nollieFsBigspin = Trick(name: "Nollie FS Bigspin", difficulty: 4, type: .shuvit, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, fsBigspin])])
    let nollieHardflip = Trick(name: "Nollie Hardflip", difficulty: 5, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, hardflip])])
    let nollieHeelflip = Trick(name: "Nollie Heelflip", difficulty: 3, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, heelflip])])
    let nollieImpossible = Trick(name: "Nollie Impossible", difficulty: 5, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, impossible])])
    let nollieInwardHeelflip = Trick(name: "Nollie Inward Heelflip", difficulty: 4, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, inwardHeelflip])])
    let nollieKickflip = Trick(name: "Nollie Kickflip", difficulty: 3, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, kickflip])])
    let nollieLaserFlip = Trick(name: "Nollie Laser Flip", difficulty: 6, type: .flip, prerequisites: [Prerequisite(prerequisiteTricks: [nollie, laserFlip])])

    // Grinds and Slides
    let backside50_50 = Trick(name: "BS 50-50", difficulty: 3, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontside50_50 = Trick(name: "FS 50-50", difficulty: 3, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backside5_0 = Trick(name: "BS 5-0", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [backside50_50])])
    let frontside5_0 = Trick(name: "FS 5-0", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [frontside50_50])])
    let backsideCrooked = Trick(name: "BS Crooked", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideCrooked = Trick(name: "FS Crooked", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsideFeeble = Trick(name: "BS Feeble", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideFeeble = Trick(name: "FS Feeble", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsideLipslide = Trick(name: "BS Lipslide", difficulty: 4, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideLipslide = Trick(name: "FS Lipslide", difficulty: 4, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsideNosegrind = Trick(name: "BS Nosegrind", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideNosegrind = Trick(name: "FS Nosegrind", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsideNoseslide = Trick(name: "BS Noseslide", difficulty: 3, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideNoseslide = Trick(name: "FS Noseslide", difficulty: 3, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsideOvercrook = Trick(name: "BS Overcrook", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideOvercrook = Trick(name: "FS Overcrook", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsideSalad = Trick(name: "BS Salad", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideSalad = Trick(name: "FS Salad", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsideSmith = Trick(name: "BS Smith", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideSmith = Trick(name: "FS Smith", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsideSuski = Trick(name: "BS Suski", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [backside5_0, backsideSalad])])
    let frontsideSuski = Trick(name: "FS Suski", difficulty: 4, type: .grind, prerequisites: [Prerequisite(prerequisiteTricks: [frontside5_0, frontsideSalad])])
    let backsideTailslide = Trick(name: "BS Tailslide", difficulty: 4, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideTailslide = Trick(name: "FS Tailslide", difficulty: 4, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsideBluntslide = Trick(name: "BS Bluntslide", difficulty: 5, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [backsideTailslide])])
    let frontsideBluntslide = Trick(name: "FS Bluntslide", difficulty: 5, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideTailslide])])
    let backsideNosebluntSlide = Trick(name: "BS Noseblunt Slide", difficulty: 5, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [backsideNoseslide])])
    let frontsideNosebluntSlide = Trick(name: "FS Noseblunt Slide", difficulty: 5, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideNoseslide])])
    let backsideBoardslide = Trick(name: "BS Boardslide", difficulty: 3, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideBoardslide = Trick(name: "FS Boardslide", difficulty: 3, type: .slide, prerequisites: [Prerequisite(prerequisiteTricks: [])])

    // Airs and Transition
    let air540 = Trick(name: "540", difficulty: 5, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let air720 = Trick(name: "720", difficulty: 6, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [air540])])
    let air900 = Trick(name: "900", difficulty: 7, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [air720])])
    let airwalk = Trick(name: "Airwalk", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let axleDropIn = Trick(name: "Axle Drop-In", difficulty: 3, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontside50_50])])
    let backsideAxleStall = Trick(name: "BS Axle Stall", difficulty: 3, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [backside50_50])])
    let backsideCrookedStall = Trick(name: "BS Crooked Stall", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [backsideCrooked])])
    let backsideDisaster = Trick(name: "BS Disaster", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [backsideBoardslide])])
    let backsideFeebleStall = Trick(name: "BS Feeble Stall", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [backsideFeeble])])
    let backsideHurricaneStall = Trick(name: "BS Hurricane Stall", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsidePivotStall = Trick(name: "BS Pivot Stall", difficulty: 3, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [backside5_0])])
    let backsideRockNRoll = Trick(name: "BS Rock 'n' roll", difficulty: 3, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideBoardslide])])
    let backsideSmithStall = Trick(name: "BS Smith Stall", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [backsideSmith])])
    let backsideTailStall = Trick(name: "BS Tail Stall", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [backsideTailslide])])
    let benihana = Trick(name: "Benihana", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let bluntStall180Out = Trick(name: "Blunt Stall 180 Out", difficulty: 5, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideBluntslide])])
    let bluntStallPullBack = Trick(name: "Blunt Stall Pull Back", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideBluntslide])])
    let bluntStallToFakie = Trick(name: "Blunt Stall to Fakie", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideBluntslide])])
    let bodyJar = Trick(name: "Body Jar", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let cannonball = Trick(name: "Cannonball", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let christAir = Trick(name: "Christ Air", difficulty: 5, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let crailGrab = Trick(name: "Crail Grab", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let creeper = Trick(name: "Creeper", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let crossbone = Trick(name: "Crossbone", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let delmarIndy = Trick(name: "Delmar Indy", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let doubleGrab = Trick(name: "Double Grab", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let dropIn = Trick(name: "Drop-In", difficulty: 2, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let fakieNosebluntStall = Trick(name: "Fakie Noseblunt Stall", difficulty: 5, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideNosebluntSlide])])
    let fakieRock = Trick(name: "Fakie Rock", difficulty: 3, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideBoardslide])])
    let fakieTailStall = Trick(name: "Fakie Tail Stall", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frigidAir = Trick(name: "Frigid Air", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideAir = Trick(name: "FS Air", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideAxleStall = Trick(name: "FS Axle Stall", difficulty: 3, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontside50_50])])
    let frontsideCrookedStall = Trick(name: "FS Crooked Stall", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideCrooked])])
    let frontsideDisaster = Trick(name: "FS Disaster", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideBoardslide])])
    let frontsideFeebleStall = Trick(name: "FS Feeble Stall", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideFeeble])])
    let frontsideHurricaneStall = Trick(name: "FS Hurricane Stall", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideNosePick = Trick(name: "FS Nose Pick", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideNosegrind])])
    let frontsideNosebluntStall = Trick(name: "FS Noseblunt Stall", difficulty: 5, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideNosebluntSlide])])
    let frontsidePivotStall = Trick(name: "FS Pivot Stall", difficulty: 3, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontside50_50])])
    let frontsideRockNRoll = Trick(name: "FS Rock 'n' roll", difficulty: 3, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideBoardslide])])
    let frontsideSmithStall = Trick(name: "FS Smith Stall", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideSmith])])
    let frontsideSugarcaneStall = Trick(name: "FS Sugarcane Stall", difficulty: 5, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideSweeper = Trick(name: "FS Sweeper", difficulty: 3, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideTailStall = Trick(name: "FS Tail Stall", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideTailslide])])
    let grosmanGrab = Trick(name: "Grosman Grab", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let helipop = Trick(name: "Helipop", difficulty: 5, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let indy = Trick(name: "Indy", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let indyGrab = Trick(name: "Indy Grab", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let invert = Trick(name: "Invert", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let japanAir = Trick(name: "Japan Air", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let judoAir = Trick(name: "Judo Air", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let lienAir = Trick(name: "Lien Air", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let madonna = Trick(name: "Madonna", difficulty: 5, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let mcTwist = Trick(name: "McTwist", difficulty: 5, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let melancholyGrab = Trick(name: "Melancholy Grab", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let melon = Trick(name: "Melon", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let methodAir = Trick(name: "Method Air", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let muteAir = Trick(name: "Mute Air", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let noseGrab = Trick(name: "Nose Grab", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let nosePick = Trick(name: "Nose Pick", difficulty: 4, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideNosegrind])])
    let noseStall = Trick(name: "Nose Stall", difficulty: 3, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideNoseslide])])
    let nosebone = Trick(name: "Nosebone", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let nuclearGrab = Trick(name: "Nuclear Grab", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let riverdance = Trick(name: "Riverdance", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let roastbeefGrab = Trick(name: "Roastbeef Grab", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let rockToFakie = Trick(name: "Rock to Fakie", difficulty: 3, type: .transition, prerequisites: [Prerequisite(prerequisiteTricks: [frontsideBoardslide])])
    let rocketAir = Trick(name: "Rocket Air", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let sacktap = Trick(name: "Sacktap", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let salFlip = Trick(name: "Sal Flip", difficulty: 5, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let saranWrap = Trick(name: "Saran Wrap", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let seatbeltGrab = Trick(name: "Seatbelt Grab", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let slobAir = Trick(name: "Slob Air", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let stalefishGrab = Trick(name: "Stalefish Grab", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let stallfish = Trick(name: "Stallfish", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let stiffy = Trick(name: "Stiffy", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let supermanGrab = Trick(name: "Superman Grab", difficulty: 5, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let tailGrab = Trick(name: "Tail Grab", difficulty: 3, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let tailbone = Trick(name: "Tailbone", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let tuckKnee = Trick(name: "Tuck Knee", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let varial = Trick(name: "Varial", difficulty: 4, type: .air, prerequisites: [Prerequisite(prerequisiteTricks: [])])

    // Footplant Tricks
    let beanPlant = Trick(name: "Bean Plant", difficulty: 3, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let eggPlant = Trick(name: "Egg Plant", difficulty: 4, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let fastplant = Trick(name: "Fastplant", difficulty: 3, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let gymnastPlant = Trick(name: "Gymnast Plant", difficulty: 4, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let hoHo = Trick(name: "Ho-Ho", difficulty: 5, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let laybackAir = Trick(name: "Layback Air", difficulty: 4, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let millerFlip = Trick(name: "Miller Flip", difficulty: 5, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let powerOllie = Trick(name: "Power Ollie", difficulty: 3, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let sadPlant = Trick(name: "Sad Plant", difficulty: 4, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let stapleGun = Trick(name: "Staple Gun", difficulty: 4, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let texasPlant = Trick(name: "Texas Plant", difficulty: 4, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let texasTwoStep = Trick(name: "Texas Two-Step", difficulty: 4, type: .footplant, prerequisites: [Prerequisite(prerequisiteTricks: [])])

    // Balance Tricks
    let manual = Trick(name: "Manual", difficulty: 2, type: .balance, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let noseManual = Trick(name: "Nose Manual", difficulty: 3, type: .balance, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let oneFootManual = Trick(name: "One Foot Manual", difficulty: 3, type: .balance, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let oneWheelManual = Trick(name: "One Wheel Manual", difficulty: 4, type: .balance, prerequisites: [Prerequisite(prerequisiteTricks: [])])

    // Miscellaneous Freestyle and Old School Tricks
    let acidDrop = Trick(name: "Acid Drop", difficulty: 3, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let alleyOop = Trick(name: "Alley Oop", difficulty: 3, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsideBoneless = Trick(name: "BS Boneless", difficulty: 3, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let backsideWallride = Trick(name: "BS Wallride", difficulty: 4, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let bodyVarial = Trick(name: "Body Varial", difficulty: 2, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let boneless = Trick(name: "Boneless", difficulty: 3, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let caveman = Trick(name: "Caveman", difficulty: 2, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let coffin = Trick(name: "Coffin", difficulty: 2, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let daffy = Trick(name: "Daffy", difficulty: 3, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let firecracker = Trick(name: "Firecracker", difficulty: 3, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let flamingo = Trick(name: "Flamingo", difficulty: 4, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    let frontsideBoneless = Trick(name: "FS Boneless", difficulty: 3, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
   let frontsideWallride = Trick(name: "FS Wallride", difficulty: 4, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
   let hangTen = Trick(name: "Hang Ten", difficulty: 3, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
   let hippieJump = Trick(name: "Hippie Jump", difficulty: 2, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
   let pogo = Trick(name: "Pogo", difficulty: 3, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
   let primoStall = Trick(name: "Primo Stall", difficulty: 4, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
   let rollIn = Trick(name: "Roll In", difficulty: 2, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
   let strawberryMilkshake = Trick(name: "Strawberry Milkshake", difficulty: 4, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
   let streetPlant = Trick(name: "Street Plant", difficulty: 4, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
   let wallie = Trick(name: "Wallie", difficulty: 3, type: .misc, prerequisites: [Prerequisite(prerequisiteTricks: [])])
    
    ollie.dependentTricks = [DependentTricks(dependentTricks: [ollieNorth, ollieSouth, powerslide, switchOllie])]
    fs180.dependentTricks = [DependentTricks(dependentTricks: [fs360, fsHalfCab, switchFs180])]
    bs180.dependentTricks = [DependentTricks(dependentTricks: [bs360, bsHalfCab, switchBs180])]
    nollie.dependentTricks = [DependentTricks(dependentTricks: [nollieBs180, nollieFs180])]
    bs360.dependentTricks = [DependentTricks(dependentTricks: [bsCaballerial, switchBs360])]
    fs360.dependentTricks = [DependentTricks(dependentTricks: [fsCaballerial, switchFs360])]
    kickflip.dependentTricks = [DependentTricks(dependentTricks: [varialKickflip, fsKickflip, bsKickflip, treFlip])]
    heelflip.dependentTricks = [DependentTricks(dependentTricks: [varialHeelflip, fsHeelflip, bsHeelflip])]
    popShuvit.dependentTricks = [DependentTricks(dependentTricks: [varialKickflip, bsBigspin, treFlip])]
    fsPopShuvit.dependentTricks = [DependentTricks(dependentTricks: [varialHeelflip, fsBigspin])]
    bigflip.dependentTricks = [DependentTricks(dependentTricks: [biggerflip])]
    backside50_50.dependentTricks = [DependentTricks(dependentTricks: [backside5_0, backsideSmith, backsideFeeble])]
    frontside50_50.dependentTricks = [DependentTricks(dependentTricks: [frontside5_0, frontsideSmith, frontsideFeeble])]
    backside5_0.dependentTricks = [DependentTricks(dependentTricks: [backsideSuski])]
    frontside5_0.dependentTricks = [DependentTricks(dependentTricks: [frontsideSuski])]
    backsideNoseslide.dependentTricks = [DependentTricks(dependentTricks: [backsideNosebluntSlide])]
    frontsideNoseslide.dependentTricks = [DependentTricks(dependentTricks: [frontsideNosebluntSlide])]
    backsideTailslide.dependentTricks = [DependentTricks(dependentTricks: [backsideBluntslide])]
    frontsideTailslide.dependentTricks = [DependentTricks(dependentTricks: [frontsideBluntslide])]
    air540.dependentTricks = [DependentTricks(dependentTricks: [air720])]
    air720.dependentTricks = [DependentTricks(dependentTricks: [air900])]
    
    return [
        // Basic Tricks
        ollie, fs180, bs180, kickturn, nollie, fakieOllie, ticTac, bs360, fs360, bsCaballerial, fsCaballerial, bsHalfCab, fsHalfCab, ollieNorth, ollieSouth, powerslide, switchBs180, switchBs360, switchFs180, switchFs360, switchOllie,

        // Flip and Shove-It Tricks
        kickflip, heelflip, popShuvit, fsPopShuvit, varialKickflip, varialHeelflip, fsKickflip, bsKickflip, fsHeelflip, bsHeelflip, nollieBs180, nollieFs180, nollie360Flip, nollie360Hardflip, nollie360PopShuvit, nollieBsBigspin, nollieFsBigspin, nollieHardflip, nollieHeelflip, nollieImpossible, nollieInwardHeelflip, nollieKickflip, nollieLaserFlip, nollieVarialHeelflip, nollieVarialKickflip, fsBigspin, bsBigspin, treFlip, hardflip, laserFlip, bigspin, bigflip, biggerflip, shuvit, fsShuvit, nollieShuvit, nollieFsShuvit,

        // Grinds and Slides
        backside50_50, frontside50_50, backside5_0, frontside5_0, backsideCrooked, frontsideCrooked, backsideFeeble, frontsideFeeble, backsideLipslide, frontsideLipslide, backsideNosegrind, frontsideNosegrind, backsideNoseslide, frontsideNoseslide, backsideOvercrook, frontsideOvercrook, backsideSalad, frontsideSalad, backsideSmith, frontsideSmith, backsideSuski, frontsideSuski, backsideTailslide, frontsideTailslide, backsideBluntslide, frontsideBluntslide, backsideNosebluntSlide, frontsideNosebluntSlide, backsideBoardslide, frontsideBoardslide, backsideHurricaneStall, frontsideHurricaneStall,

        // Airs and Transition
        air540, air720, air900, airwalk, axleDropIn, backsideAxleStall, backsideCrookedStall, backsideDisaster, backsideFeebleStall, backsidePivotStall, backsideRockNRoll, backsideSmithStall, backsideTailStall, benihana, bluntStall180Out, bluntStallPullBack, bluntStallToFakie, bodyJar, cannonball, christAir, crailGrab, creeper, crossbone, delmarIndy, doubleGrab, dropIn, fakieNosebluntStall, fakieRock, fakieTailStall, frigidAir, frontsideAir, frontsideAxleStall, frontsideCrookedStall, frontsideDisaster, frontsideFeebleStall, frontsideNosePick, frontsideNosebluntStall, frontsidePivotStall, frontsideRockNRoll, frontsideSmithStall, frontsideSugarcaneStall, frontsideSweeper, frontsideTailStall, grosmanGrab, helipop, indy, indyGrab, invert, japanAir, judoAir, lienAir, madonna, mcTwist, melancholyGrab, melon, methodAir, muteAir, noseGrab, nosePick, noseStall, nosebone, nuclearGrab, riverdance, roastbeefGrab, rockToFakie, rocketAir, sacktap, salFlip, saranWrap, seatbeltGrab, slobAir, stalefishGrab, stallfish, stiffy, supermanGrab, tailGrab, tailbone, tuckKnee, varial,

        // Footplant Tricks
        beanPlant, eggPlant, fastplant, gymnastPlant, hoHo, laybackAir, millerFlip, powerOllie, sadPlant, stapleGun, texasPlant, texasTwoStep,

        // Balance Tricks
        manual, noseManual, oneFootManual, oneWheelManual,

        // Miscellaneous Freestyle and Old School Tricks
        acidDrop, alleyOop, backsideBoneless, backsideWallride, bodyVarial, boneless, caveman, coffin, daffy, firecracker, flamingo, frontsideBoneless, frontsideWallride, hangTen, hippieJump, pogo, primoStall, rollIn, strawberryMilkshake, streetPlant, wallie
    ]
}
