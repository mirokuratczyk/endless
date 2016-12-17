//
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

#import <Foundation/Foundation.h>
#import "LogViewController.h"
#import "PsiphonBrowser-Swift.h"


@implementation LogViewController {
    UITableView *tableView;
}

- (void)viewDidLoad
{
    tableView = [[UITableView alloc] init];
    tableView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:tableView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newLogsAdded:) //note the ":" - should take an NSNotification as parameter
                                                 name:@"DisplayLogEntry"
                                               object:nil];
}

-(void)newLogsAdded:(id)sender
{
    [tableView reloadData];
    
    // Scroll to bottom
    NSIndexPath* ipath = [NSIndexPath indexPathForRow: [[[PsiphonData sharedInstance] getStatusHistory] count]-1 inSection: 0];
    [tableView scrollToRowAtIndexPath: ipath atScrollPosition: UITableViewScrollPositionTop animated: YES];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = [[[PsiphonData sharedInstance] getStatusHistory] count];
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"cell";
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSArray *statusEntries = [[PsiphonData sharedInstance] getStatusHistoryForDisplay];
    NSString *statusEntryForDisplay = statusEntries[indexPath.row];
    
    cell.textLabel.text = statusEntryForDisplay;
    [cell.textLabel setLineBreakMode:NSLineBreakByWordWrapping];
    [cell.textLabel setNumberOfLines:0];
    [cell.textLabel setFont:[UIFont fontWithName:@"Helvetica" size:12.0f]];
    
    return cell;
}

@end
