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

#import "RegionAdapter.h"
#import "RegionSelectionViewController.h"

@implementation RegionSelectionViewController {
    RegionAdapter *regionAdapter;
    NSString *selectedRegion;
    NSMutableArray *regions;
    NSInteger selectedRow;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    regionAdapter = [RegionAdapter sharedInstance];
    regions = [[NSMutableArray alloc] initWithArray:[regionAdapter getRegions]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAvailableRegions:) name:kPsiphonAvailableRegionsNotification object:nil];

    self.table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.table.delegate = self;
    self.table.dataSource = self;

    self.table.tableHeaderView = nil;
    self.table.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;

    [self.view addSubview:self.table];
}

#pragma mark - UITableView delegate methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Region *r = [regions objectAtIndex:indexPath.row];

    NSString *identifier = [NSString stringWithFormat:@"%@", r.code];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }

    cell.imageView.image = [UIImage imageNamed:r.flagResourceId];
    cell.textLabel.text = r.title;
    cell.userInteractionEnabled = YES;
    cell.hidden = !r.serverExists;

    if ([r.code isEqualToString:[regionAdapter getSelectedRegion].code]) {
        selectedRow = indexPath.row;
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // New region was selected update tableview cells

    // De-select cell of currently selected region
    NSUInteger currentIndex[2];
    currentIndex[0] = 0;
    currentIndex[1] = selectedRow;
    NSIndexPath *currentIndexPath = [[NSIndexPath alloc] initWithIndexes:currentIndex length:2];
    UITableViewCell *currentlySelectedCell = [tableView cellForRowAtIndexPath:currentIndexPath];
    currentlySelectedCell.accessoryType = UITableViewStylePlain; // Remove checkmark

    // Select cell of newly chosen region
    Region *r = [regions objectAtIndex:indexPath.row];
    selectedRow = indexPath.row;
    selectedRegion = r.code;
    [regionAdapter setSelectedRegion:selectedRegion];

    NSIndexPath *newIndexPath = [tableView indexPathForSelectedRow];
    UITableViewCell *newlySelectedCell = [tableView cellForRowAtIndexPath:newIndexPath];
    newlySelectedCell.accessoryType = UITableViewCellAccessoryCheckmark;
    [tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    Region *r = [regions objectAtIndex:indexPath.row];
    return r.serverExists ? 44.0f : 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return regions.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

#pragma mark - Notifications

- (void) updateAvailableRegions:(NSNotification*) notification {
    [self.table reloadData];
}

@end
