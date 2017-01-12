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
    NSArray *logs;
    UITableView *table;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newLogAdded:)
                                                 name:@"DisplayLogEntry"
                                               object:nil];

    logs = [[PsiphonData sharedInstance] getDiagnosticLogs];

    table = [[UITableView alloc] init];
    table.dataSource = self;
    table.delegate = self;
    table.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    table.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    table.estimatedRowHeight = 60;
    table.rowHeight = UITableViewAutomaticDimension;

    [self.view addSubview:table];
    [self scrollToBottom];
}

#pragma mark - UITableView delegate methods

// Scroll to bottom of UITableView
-(void)scrollToBottom
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *myIndexPath = [NSIndexPath indexPathForRow:[logs count]-1 inSection:0];
        [table selectRowAtIndexPath:myIndexPath animated:NO scrollPosition:UITableViewScrollPositionBottom];
    });
}

// Reload data and scroll to bottom of UITableView
-(void)newLogAdded:(id)sender
{
    logs = [[PsiphonData sharedInstance] getDiagnosticLogs];
    [table reloadData];
    [self scrollToBottom];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [logs count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *statusEntryForDisplay = logs[indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:statusEntryForDisplay];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:statusEntryForDisplay];
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [UIFont fontWithName:@"Helvetica" size:12.0f];
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.text = statusEntryForDisplay;
    
    return cell;
}

@end
