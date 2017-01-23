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

#import <UIKit/UIKit.h>
#import <XLForm/XLForm.h>
#import "PsiphonSettings.h"
#import "SettingsViewController.h"
#import "UpstreamProxySettings.h"

@implementation PsiphonSettingsViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initializeForm];
    }
    return self;
}

- (void)initializeForm
{
    const NSString *optional = NSLocalizedString(@"Optional", @"");
    const NSString *required = NSLocalizedString(@"Required", @"");
    UpstreamProxySettings *proxySettings = [UpstreamProxySettings sharedInstance];
    
    XLFormDescriptor * formDescriptor = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"Psiphon Settings", @"")];
    XLFormSectionDescriptor * section;
    XLFormRowDescriptor * row;
    
    // Timeouts section
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"Timeouts", @"")];
    [formDescriptor addFormSection:section];
    
    // Timeouts
    row = [XLFormRowDescriptor formRowDescriptorWithTag:kDisableTimeouts rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"Disable Timeouts", @"")];
    row.value = @0;
    [section addFormRow:row];
    
    // Proxy section
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"Proxy", @"")];
    [formDescriptor addFormSection:section];
    
    // Use upstream proxy
    row = [XLFormRowDescriptor formRowDescriptorWithTag:kUseProxy rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"Use upstream proxy", @"")];
    row.value = [NSNumber numberWithBool:[proxySettings getUseCustomProxySettings]];
    [section addFormRow:row];
    
    // Host address
    row = [XLFormRowDescriptor formRowDescriptorWithTag:kProxyHostAddress rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"Host address", @"")];
    [row.cellConfigAtConfigure setObject:required forKey:@"textField.placeholder"];
    [row.cellConfigAtConfigure setObject:@(NSTextAlignmentRight) forKey:@"textField.textAlignment"];
    row.required = YES;
    row.value = [proxySettings getCustomProxyHost];
    row.disabled = [NSString stringWithFormat:@"$%@==0", kUseProxy];
    [section addFormRow:row];
    
    // Port
    row = [XLFormRowDescriptor formRowDescriptorWithTag:kProxyPort rowType:XLFormRowDescriptorTypeInteger title:NSLocalizedString(@"Port", @"")];
    [row.cellConfigAtConfigure setObject:required forKey:@"textField.placeholder"];
    [row.cellConfigAtConfigure setObject:@(NSTextAlignmentRight) forKey:@"textField.textAlignment"];
    row.required = YES;
    row.value = [proxySettings getCustomProxyPort];
    row.disabled = [NSString stringWithFormat:@"$%@==0", kUseProxy];
    [section addFormRow:row];
    
    // Use proxy authentication
    row = [XLFormRowDescriptor formRowDescriptorWithTag:kUseProxyAuthentication rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"Use proxy authentication", @"")];
    row.value = [NSNumber numberWithBool:[proxySettings getUseProxyAuthentication]];
    row.disabled = [NSString stringWithFormat:@"$%@==0", kUseProxy];
    [section addFormRow:row];
    
    // Proxy username
    row = [XLFormRowDescriptor formRowDescriptorWithTag:kProxyUsername rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"Proxy username", @"")];
    [row.cellConfigAtConfigure setObject:required forKey:@"textField.placeholder"];
    [row.cellConfigAtConfigure setObject:@(NSTextAlignmentRight) forKey:@"textField.textAlignment"];
    row.required = YES;
    row.value = [proxySettings getProxyUsername];
    row.hidden = [NSString stringWithFormat:@"($%@ == 0) OR ($%@ == 0)", kUseProxy, kUseProxyAuthentication];
    [section addFormRow:row];
    
    // Proxy password
    row = [XLFormRowDescriptor formRowDescriptorWithTag:kProxyPassword rowType:XLFormRowDescriptorTypePassword title:NSLocalizedString(@"Proxy password", @"")];
    [row.cellConfigAtConfigure setObject:required forKey:@"textField.placeholder"];
    [row.cellConfigAtConfigure setObject:@(NSTextAlignmentRight) forKey:@"textField.textAlignment"];
    row.required = YES;
    row.value = [proxySettings getProxyPassword];
    row.hidden = [NSString stringWithFormat:@"($%@ == 0) OR ($%@ == 0)", kUseProxy, kUseProxyAuthentication];
    [section addFormRow:row];
    
    // Proxy domain
    row = [XLFormRowDescriptor formRowDescriptorWithTag:kProxyDomain rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"Proxy domain", @"")];
    [row.cellConfigAtConfigure setObject:optional forKey:@"textField.placeholder"];
    [row.cellConfigAtConfigure setObject:@(NSTextAlignmentRight) forKey:@"textField.textAlignment"];
    row.required = YES;
    row.value = [proxySettings getProxyDomain];
    row.hidden = [NSString stringWithFormat:@"($%@ == 0) OR ($%@ == 0)", kUseProxy, kUseProxyAuthentication];
    [section addFormRow:row];
    
    self.form = formDescriptor;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", @"") style:UIBarButtonItemStyleDone target:self action:@selector(validateForm:)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"") style:UIBarButtonItemStyleDone target:self action:@selector(quit)];
}

#pragma mark - actions

- (void)quit {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)validateForm:(UIBarButtonItem *)buttonItem
{
    BOOL proxySettingsValid = YES; // = !proxyEnabled || ((validPort && validHostAddress) && (!proxyAuthenticationEnabled || (validUsername && validPassword && validDomain)));
    
    NSDictionary *formValues = [self formValues];
    BOOL proxyEnabled = [[formValues objectForKey:kUseProxy] boolValue];
    
    if (proxyEnabled) {
        // TODO: proper validation for these fields
        BOOL validPort = [self isValidPortInput:[formValues objectForKey:kProxyPort]];
        BOOL validHostAddress = [self isValidHostAddress:[formValues objectForKey:kProxyHostAddress]];
        
        proxySettingsValid = proxySettingsValid && validPort && validHostAddress;
        
        BOOL proxyAuthenticationEnabled = [[formValues objectForKey:kUseProxyAuthentication] boolValue];
        if (proxyAuthenticationEnabled) {
            BOOL validUsername = [self isValidUsername:[formValues objectForKey:kProxyUsername]];
            BOOL validPassword = [self isValidPassword:[formValues objectForKey:kProxyPassword]];
            BOOL validDomain = [self isValidDomain:[formValues objectForKey:kProxyDomain]];

            proxySettingsValid = proxySettingsValid && validUsername && validPassword && validDomain;
        }
    }
    
    if (proxySettingsValid) { // Set and dismiss
        [self persistSettings];
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    }
}
                                             
- (void)persistSettings {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *formValues = [self formValues];
    
    for (NSString* field in formValues) {
        [userDefaults setValue:[formValues objectForKey:field] forKey:field];
    }
}

#pragma mark - validation

// TODO: check for float
- (BOOL)isValidPortInput:(id)obj {
    if (obj != [NSNull null] && [obj isKindOfClass:[NSNumber class]]) {
            NSInteger port = [obj integerValue];
            if (port >= 1 && port <= 65535) {
                return YES;
            }
    }
    [self animateField:kProxyPort];
    return NO;
}

// TODO: proper validation
- (BOOL)isValidHostAddress:(id)obj {
    if (obj != [NSNull null]) {
        NSString *value = obj;
        if ([value length] > 0) {
            return YES;
        }
    }
    [self animateField:kProxyHostAddress];
    return NO;
}

// TODO: proper validation
- (BOOL)isValidUsername:(id)obj {
    if (obj != [NSNull null]) {
        NSString *value = obj;
        if ([value length] > 0) {
            return YES;
        }
    }
    [self animateField:kProxyUsername];
    return NO;
}

// TODO: proper validation
- (BOOL)isValidPassword:(id)obj {
    if (obj != [NSNull null]) {
        NSString *value = obj;
        if ([value length] > 0) {
            return YES;
        }
    }
    [self animateField:kProxyPassword];
    return NO;
}

// TODO: proper validation
- (BOOL)isValidDomain:(id)obj {
    return YES;
}

- (void)animateField:(NSString *)field {
    UITableViewCell * cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:[self.form formRowWithTag:field]]];
    [self animateCell:cell];
}

#pragma mark - Animation

- (void)animateCell:(UITableViewCell *)cell
{
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    animation.keyPath = @"position.x";
    animation.values =  @[ @0, @20, @-20, @10, @0];
    animation.keyTimes = @[@0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1];
    animation.duration = 0.3;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.additive = YES;
    
    [cell.layer addAnimation:animation forKey:@"shake"];
    
    // TODO: remove
    cell.backgroundColor = [UIColor orangeColor];
    [UIView animateWithDuration:1 animations:^{
        cell.backgroundColor = [UIColor whiteColor];
    }];
}

@end
