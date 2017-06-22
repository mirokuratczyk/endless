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

@implementation Region

@synthesize code = _code;
@synthesize flagResourceId = _flagResourceId;
@synthesize serverExists = _serverExists;

- (id) init {
	self = [super init];
	return self;
}

- (id) initWithParams:(NSString*)regionCode andResourceId:(NSString*)pathToFlagResource exists:(BOOL) exists {
	self = [super init];
	if (self) {
		_code = regionCode;
		_flagResourceId = pathToFlagResource;
		_serverExists = exists;
	}
	return self;
}

- (void)setRegionExists:(BOOL)exists {
	_serverExists = exists;
}

@end

@implementation RegionAdapter {
	NSMutableArray *flags;
	NSMutableArray *regions;
	NSDictionary *regionTitles;
	NSString *selectedRegion;
}

- (id)init {
	self = [super init];
	selectedRegion = [[NSUserDefaults standardUserDefaults] stringForKey:kRegionSelectionSpecifierKey];

	if (selectedRegion == nil) {
		selectedRegion = kPsiphonRegionBestPerformance;
	}

	regions = [[NSMutableArray alloc] initWithArray:
			   @[[[Region alloc] initWithParams:kPsiphonRegionBestPerformance andResourceId:@"flag-best-performance" exists:YES],
				 [[Region alloc] initWithParams:@"CA" andResourceId:@"flag-ca" exists:NO],
				 [[Region alloc] initWithParams:@"DE" andResourceId:@"flag-de" exists:NO],
				 [[Region alloc] initWithParams:@"ES" andResourceId:@"flag-es" exists:NO],
				 [[Region alloc] initWithParams:@"GB" andResourceId:@"flag-gb" exists:NO],
				 [[Region alloc] initWithParams:@"HK" andResourceId:@"flag-hk" exists:NO],
				 [[Region alloc] initWithParams:@"IN" andResourceId:@"flag-in" exists:NO],
				 [[Region alloc] initWithParams:@"JP" andResourceId:@"flag-jp" exists:NO],
				 [[Region alloc] initWithParams:@"NL" andResourceId:@"flag-nl" exists:NO],
				 [[Region alloc] initWithParams:@"SG" andResourceId:@"flag-sg" exists:NO],
				 [[Region alloc] initWithParams:@"US" andResourceId:@"flag-us" exists:NO]]];

	regionTitles = [RegionAdapter getLocalizedRegionTitles];

	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	return self;
}

+ (NSDictionary*)getLocalizedRegionTitles {
	return @{
			 kPsiphonRegionBestPerformance: NSLocalizedString(@"Best Performance",@"The name of the pseudo-region a user can select if they want to use a Psiphon server with the best performance -- speed, latency, etc., rather than specify a particular region/country. This appears in a combo box and should be kept short."),
			 @"CA": NSLocalizedString(@"Canada", @"Name of a country/region where Psiphon servers are located. The user can choose to only use servers in that country."),
			 @"DE": NSLocalizedString(@"Germany",@"Name of a country/region where Psiphon servers are located. The user can choose to only use servers in that country."),
			 @"ES": NSLocalizedString(@"Spain", @"Name of a country/region where Psiphon servers are located. The user can choose to only use servers in that country."),
			 @"GB": NSLocalizedString(@"United Kingdom", @"Name of a country/region where Psiphon servers are located. The user can choose to only use servers in that country."),
			 @"HK": NSLocalizedString(@"Hong Kong", @"Name of a country/region where Psiphon servers are located. The user can choose to only use servers in that country."),
			 @"IN": NSLocalizedString(@"India", @"Name of a country/region where Psiphon servers are located. The user can choose to only use servers in that country."),
			 @"JP": NSLocalizedString(@"Japan", @"Name of a country/region where Psiphon servers are located. The user can choose to only use servers in that country."),
			 @"NL": NSLocalizedString(@"Netherlands", @"Name of a country/region where Psiphon servers are located. The user can choose to only use servers in that country."),
			 @"SG": NSLocalizedString(@"Singapore", @"Name of a country/region where Psiphon servers are located. The user can choose to only use servers in that country."),
			 @"US": NSLocalizedString(@"United States", @"Name of a country/region where Psiphon servers are located. The user can choose to only use servers in that country.")
			 };
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

// Localizes the region titles for display in the settings menu
// This should be called whenever the app language is changed
- (void)reloadTitlesForNewLocalization {
	regionTitles = [NSMutableDictionary dictionaryWithDictionary:[RegionAdapter getLocalizedRegionTitles]];
}

- (void)onAvailableEgressRegions: (NSArray*)availableEgressRegions {
	// If selected region is no longer available select best performance and restart
	if (![selectedRegion isEqualToString:kPsiphonRegionBestPerformance] && ![availableEgressRegions containsObject:selectedRegion]) {
		selectedRegion = kPsiphonRegionBestPerformance;
		[appDelegate scheduleRunningTunnelServiceRestart];
	}

	// Should use a dictionary for performance if # of regions ever increases dramatically
	for (Region *region in regions) {
		[region setRegionExists:([region.code isEqualToString:kPsiphonRegionBestPerformance] || [availableEgressRegions containsObject:region.code])];
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
	[self notifySelectedNewRegion];
}

- (NSString*)getLocalizedRegionTitle:(NSString*)regionCode {
	NSString *localizedTitle = [regionTitles objectForKey:regionCode];
	if (localizedTitle.length == 0) {
		return @"";
	}
	return localizedTitle;
}

- (void)notifyAvailableRegionsChanged {
	[[NSNotificationCenter defaultCenter]
	 postNotificationName:kPsiphonAvailableRegionsNotification
	 object:self
	 userInfo:nil];
}

-(void)notifySelectedNewRegion {
	[[NSNotificationCenter defaultCenter]
	 postNotificationName:kPsiphonSelectedNewRegionNotification
	 object:self
	 userInfo:nil];
}

@end
