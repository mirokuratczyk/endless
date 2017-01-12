/*
 * Copyright (c) 2016, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "AppDelegate.h"
#import "RegionAdapter.h"

static AppDelegate *appDelegate;

@implementation Region {
}

- (id) init {
    self = [super init];
    return self;
}

- (id) initWithParams:(NSString*)regionCode andResourceId:(NSString*)pathToFlagResouce andTitle:(NSString*)regionTitle exists:(BOOL) exists {
    self = [super init];
    if (self) {
        self.code = regionCode;
        self.flagResourceId = pathToFlagResouce;
        self.serverExists = exists;
        self.title = regionTitle;
    }
    return self;
}

@end

@implementation RegionAdapter {
    NSMutableArray *flags;
    NSMutableArray *regions;
    NSString *selectedRegion;
}

- (id)init {
    self = [super init];
    selectedRegion = [[NSUserDefaults standardUserDefaults] stringForKey:kRegionSelectionSpecifierKey];

    if (selectedRegion == nil) {
        selectedRegion = kPsiphonRegionBestPerformance;
    }

    regions =[[NSMutableArray alloc] initWithArray:
              @[[[Region alloc] initWithParams:kPsiphonRegionBestPerformance andResourceId:@"flag-best-performance" andTitle:NSLocalizedString(@"Best Performance","") exists:YES],
                [[Region alloc] initWithParams:@"CA" andResourceId:@"flag-ca" andTitle:NSLocalizedString(@"Canada","") exists:NO],
                [[Region alloc] initWithParams:@"DE" andResourceId:@"flag-de" andTitle:NSLocalizedString(@"Germany","") exists:NO],
                [[Region alloc] initWithParams:@"ES" andResourceId:@"flag-es" andTitle:NSLocalizedString(@"Spain","") exists:NO],
                [[Region alloc] initWithParams:@"GB" andResourceId:@"flag-gb" andTitle:NSLocalizedString(@"United Kingdom","") exists:NO],
                [[Region alloc] initWithParams:@"HK" andResourceId:@"flag-hk" andTitle:NSLocalizedString(@"Hong Kong","") exists:NO],
                [[Region alloc] initWithParams:@"IN" andResourceId:@"flag-in" andTitle:NSLocalizedString(@"India","") exists:NO],
                [[Region alloc] initWithParams:@"JP" andResourceId:@"flag-jp" andTitle:NSLocalizedString(@"Japan","") exists:NO],
                [[Region alloc] initWithParams:@"NL" andResourceId:@"flag-nl" andTitle:NSLocalizedString(@"Netherlands","") exists:NO],
                [[Region alloc] initWithParams:@"SG" andResourceId:@"flag-sg" andTitle:NSLocalizedString(@"Singapore","") exists:NO],
                [[Region alloc] initWithParams:@"US" andResourceId:@"flag-us" andTitle:NSLocalizedString(@"United States","") exists:NO]]];

    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    return self;
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)onAvailableEgressRegions: (NSArray*)availableEgressRegions {
    // If selected region is no longer available select best performance and restart
    if (![selectedRegion isEqualToString:kPsiphonRegionBestPerformance] && ![availableEgressRegions containsObject:selectedRegion]) {
        selectedRegion = kPsiphonRegionBestPerformance;
        [appDelegate scheduleRunningTunnelServiceRestart];
    }

    // Should use a dictionary for performance if # of regions ever increases dramatically
    for (Region *region in regions) {
        region.serverExists = [region.code isEqualToString:kPsiphonRegionBestPerformance] || [availableEgressRegions containsObject:region.code];
    }

    [self notifyAvailableRegionsChanged];
}

- (NSArray*)getRegions {
    return [regions copy];
}

- (Region*)getSelectedRegion {
    for (Region *region in regions) {
        if ([region.code isEqualToString:selectedRegion]) {
            return region;
        }
    }
    return nil;
}

- (void)setSelectedRegion:(NSString*)regionCode {
    selectedRegion = regionCode;
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setValue:selectedRegion forKey:kRegionSelectionSpecifierKey];
}

- (void)notifyAvailableRegionsChanged {
    [[NSNotificationCenter defaultCenter]
     postNotificationName:kPsiphonAvailableRegionsNotification
     object:self
     userInfo:nil];
}

@end
