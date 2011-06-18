//
//  AppConstants.h
//  AquaticPrime Developer
//
//  Created by Mark Lilback on 6/16/11.
//  Copyright 2011 Agile Monks. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DATADIR_DEFAULTS_KEY @"DataDirPath"

#define DATADIR_PATH [[[NSUserDefaults standardUserDefaults] objectForKey:DATADIR_DEFAULTS_KEY] stringByExpandingTildeInPath]