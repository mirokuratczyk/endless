/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "HostSettings.h"
#import "HostSettingsController.h"

#import "QuickDialog.h"

@implementation HostSettingsController

AppDelegate *appDelegate;
NSMutableArray *_sortedHosts;
NSString *firstMatch;

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	self.title = NSLocalizedString(@"Host Settings", nil);
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addHost:)];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil)
                                                                             style:UIBarButtonItemStyleDone target:self.navigationController
                                                                            action:@selector(dismissModalViewControllerAnimated:)];
	
	/* most likely the user is wanting to define the site they are currently on, so feed that as a reasonable default the first time around */
	if ([[appDelegate webViewController] curWebViewTab] != nil) {
		NSURL *t = [[[appDelegate webViewController] curWebViewTab] url];
		if (t != nil && [t host] != nil) {
			NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"^www\\." options:NSRegularExpressionCaseInsensitive error:nil];
			
			firstMatch = [r stringByReplacingMatchesInString:[t host] options:0 range:NSMakeRange(0, [[t host] length]) withTemplate:@""];
		}
	}
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[self sortedHosts] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"host"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"host"];
	
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	HostSettings *hs = [HostSettings forHost:[[self sortedHosts] objectAtIndex:indexPath.row]];
	cell.textLabel.text = [hs hostname];
	if ([hs isDefault])
		cell.textLabel.font = [UIFont boldSystemFontOfSize:cell.textLabel.font.pointSize];
	else
		cell.detailTextLabel.text = nil;

	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return (indexPath.row != 0);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self showDetailsForHost:[[self sortedHosts] objectAtIndex:indexPath.row]];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		if ([HostSettings removeSettingsForHost:[[self sortedHosts] objectAtIndex:indexPath.row]]) {
			[HostSettings persist];
			_sortedHosts = nil;
			[[self tableView] reloadData];
		}
	}
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (void)addHost:sender
{
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Host settings", nil)
                                                                             message:NSLocalizedString(@"Enter the host/domain to define settings for", nil)
                                                                      preferredStyle:UIAlertControllerStyleAlert];
	[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = @"example.com";
		
		if (firstMatch != nil)
			textField.text = firstMatch;
	}];
	
	UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		UITextField *host = alertController.textFields.firstObject;
		if (host && ![[host text] isEqualToString:@""]) {
			HostSettings *hs = [[HostSettings alloc] initForHost:[host text] withDict:nil];
			[hs save];
			[HostSettings persist];
			_sortedHosts = nil;
			
			[self.tableView reloadData];
			[self showDetailsForHost:[host text]];
		}
	}];
	
	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
	[alertController addAction:cancelAction];
	[alertController addAction:okAction];
	
	[self presentViewController:alertController animated:YES completion:nil];
	
	firstMatch = nil;
}

- (NSMutableArray *)sortedHosts
{
	if (_sortedHosts == nil)
		_sortedHosts = [[NSMutableArray alloc] initWithArray:[HostSettings sortedHosts]];
	
	return _sortedHosts;
}

- (void)showDetailsForHost:(NSString *)thost
{
	HostSettings *host = [HostSettings forHost:thost];
	
	QRootElement *root = [[QRootElement alloc] init];
	root.grouped = YES;
	root.appearance = [root.appearance copy];
	
	root.appearance.labelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
	root.appearance.valueColorEnabled = [UIColor darkTextColor];
	
	root.title = [host hostname];
	
	QSection *section = [[QSection alloc] init];
	
	QEntryElement *hostname;
	if ([host isDefault]) {
		QLabelElement *label = [[QLabelElement alloc] initWithTitle:NSLocalizedString(@"Host/domain", nil) Value:HOST_SETTINGS_HOST_DEFAULT_LABEL];
		[section addElement:label];
		[section setFooter:NSLocalizedString(@"These settings will be used as defaults for all hosts unless overridden", nil)];
	}
	else {
		hostname = [[QEntryElement alloc] initWithTitle:NSLocalizedString(@"Host/domain", nil) Value:[host hostname] Placeholder:@"example.com"];
		[section addElement:hostname];
		[section setFooter:NSLocalizedString(@"These settings will apply to all hosts under this domain", nil)];
	}
	
	[root addSection:section];
	
	/* security section */
	
	section = [[QSection alloc] init];
	[section setTitle:NSLocalizedString(@"Security", nil)];
	
	/* tls version */
	
	NSMutableArray *i = [[NSMutableArray alloc] init];
	if (![host isDefault])
		[i addObject:NSLocalizedString(@"Default", nil)];
	[i addObjectsFromArray:@[ NSLocalizedString(@"TLS 1.2 Only", nil), NSLocalizedString(@"TLS 1.2, 1.1, or 1.0", nil) ]];

	QRadioElement *tls = [[QRadioElement alloc] initWithItems:i selected:0];
	
	i = [[NSMutableArray alloc] init];
	if (![host isDefault])
		[i addObject:HOST_SETTINGS_DEFAULT];
	[i addObjectsFromArray:@[ HOST_SETTINGS_TLS_12, HOST_SETTINGS_TLS_AUTO ]];
	[tls setValues:i];
	
	[tls setTitle:NSLocalizedString(@"TLS version", nil)];
	NSString *tlsval = [host setting:HOST_SETTINGS_KEY_TLS];
	
    if (tlsval == nil)
		[tls setSelectedValue:HOST_SETTINGS_DEFAULT];
	else
		[tls setSelectedValue:tlsval];
    
    if ([host isDefault])
        [section setFooter:NSLocalizedString(@"Minimum version of TLS required by hosts to negotiate HTTPS connections", nil)];
    else
        [section setFooter:NSLocalizedString(@"Minimum version of TLS required by this host to negotiate HTTPS connections", nil)];
    
	[section addElement:tls];
	[root addSection:section];
	
	section = [[QSection alloc] init];
	
	/* content policy */
	
	i = [[NSMutableArray alloc] init];
	if (![host isDefault])
		[i addObject:NSLocalizedString(@"Default", nil)];
	[i addObjectsFromArray:@[ NSLocalizedString(@"Open (normal browsing mode)", nil), NSLocalizedString(@"No XHR/WebSockets/Video connections", nil),NSLocalizedString( @"Strict (no JavaScript, video, etc.)", nil)]];
	
	QRadioElement *csp = [[QRadioElement alloc] initWithItems:i selected:0];
	
	i = [[NSMutableArray alloc] init];
	if (![host isDefault])
		[i addObject:HOST_SETTINGS_DEFAULT];
	[i addObjectsFromArray:@[ HOST_SETTINGS_CSP_OPEN, HOST_SETTINGS_CSP_BLOCK_CONNECT, HOST_SETTINGS_CSP_STRICT ]];
	[csp setValues:i];
	
	[csp setTitle:NSLocalizedString(@"Content policy", nil)];
	NSString *cspval = [host setting:HOST_SETTINGS_KEY_CSP];
	if (cspval == nil)
		[csp setSelectedValue:HOST_SETTINGS_DEFAULT];
	else
		[csp setSelectedValue:cspval];
    if([host isDefault])
        [section setFooter:NSLocalizedString(@"Restrictions on resources loaded from web pages", nil)];
    else
        [section setFooter:NSLocalizedString(@"Restrictions on resources loaded from web pages at this host", nil)];
	[section addElement:csp];
	[root addSection:section];
	
	/* block external lan requests */
	
	section = [[QSection alloc] init];
	
	QRadioElement *exlan = [self yesNoRadioElementWithDefault:(![host isDefault])];
	[exlan setTitle:NSLocalizedString(@"Block external LAN requests", nil)];
	NSString *val = [host setting:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS];
	if (val == nil)
		val = HOST_SETTINGS_DEFAULT;
	[exlan setSelectedValue:val];
	[section addElement:exlan];
    if([host isDefault])
        [section setFooter:NSLocalizedString(@"Resources loaded from hosts will be blocked from loading page elements or making requests to LAN hosts (192.168.0.0/16, 172.16.0.0/12, etc.)", nil)] ;
    else
        [section setFooter:NSLocalizedString(@"Resources loaded from this host will be blocked from loading page elements or making requests to LAN hosts (192.168.0.0/16, 172.16.0.0/12, etc.)", nil)] ;
	[root addSection:section];
	
	/* mixed-mode resources */
	
	section = [[QSection alloc] init];
	QRadioElement *allowmixedmode = [self yesNoRadioElementWithDefault:(![host isDefault])];
	[allowmixedmode setTitle:NSLocalizedString(@"Allow mixed-mode resources", nil)];
	val = [host setting:HOST_SETTINGS_KEY_ALLOW_MIXED_MODE];
	if (val == nil)
		val = HOST_SETTINGS_DEFAULT;
	[allowmixedmode setSelectedValue:val];
	[section addElement:allowmixedmode];
    if([host isDefault])
	[section setFooter:NSLocalizedString(@"Allow HTTPS hosts to load page resources from non-HTTPS hosts (useful for RSS readers and other aggregators)", nil)];
        else
            [section setFooter:NSLocalizedString(@"Allow this HTTPS host to load page resources from non-HTTPS hosts (useful for RSS readers and other aggregators)", nil)];
	[root addSection:section];
	
	/* privacy section */
	
	section = [[QSection alloc] init];
	[section setTitle:NSLocalizedString(@"Privacy", nil)];
	
	/* whitelist cookies */
	
	QRadioElement *whitelistCookies = [self yesNoRadioElementWithDefault:(![host isDefault])];
	[whitelistCookies setTitle:NSLocalizedString(@"Allow persistent cookies", nil)];
	val = [host setting:HOST_SETTINGS_KEY_WHITELIST_COOKIES];
	if (val == nil)
		val = HOST_SETTINGS_DEFAULT;
	[whitelistCookies setSelectedValue:val];
	[section addElement:whitelistCookies];
	
	[root addSection:section];
	
	QuickDialogController *qdc = [QuickDialogController controllerForRoot:root];
	
	[qdc setWillDisappearCallback:^{
		if (![host isDefault])
			[host setHostname:[hostname textValue]];
		
		[host setSetting:HOST_SETTINGS_KEY_TLS toValue:(NSString *)[tls selectedValue]];
		[host setSetting:HOST_SETTINGS_KEY_CSP toValue:(NSString *)[csp selectedValue]];
		[host setSetting:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS toValue:(NSString *)[exlan selectedValue]];
		[host setSetting:HOST_SETTINGS_KEY_WHITELIST_COOKIES toValue:(NSString *)[whitelistCookies selectedValue]];
		[host setSetting:HOST_SETTINGS_KEY_ALLOW_MIXED_MODE toValue:(NSString *)[allowmixedmode selectedValue]];

		[host save];
		[HostSettings persist];
	}];
	
	[[self navigationController] pushViewController:qdc animated:YES];
	self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Hosts", nil) style:UIBarButtonItemStylePlain target:nil action:nil];
}

- (QRadioElement *)yesNoRadioElementWithDefault:(BOOL)withDefault
{
	NSMutableArray *items = [[NSMutableArray alloc] init];
	if (withDefault)
		[items addObject:NSLocalizedString(@"Default", @"Setting value for Default/Yes/No radiobutton group")];
	[items addObjectsFromArray:@[ NSLocalizedString(@"Yes", @"Setting value for Default/Yes/No radiobutton group"), NSLocalizedString(@"No", @"Setting value for Default/Yes/No radiobutton group")]];
	
	QRadioElement *opt = [[QRadioElement alloc] initWithItems:items selected:0];
	
	NSMutableArray *vals = [[NSMutableArray alloc] init];
	if (withDefault)
		[vals addObject:HOST_SETTINGS_DEFAULT];
	[vals addObjectsFromArray:@[ HOST_SETTINGS_VALUE_YES, HOST_SETTINGS_VALUE_NO ]];
	[opt setValues:vals];
	
	return opt;
}

@end
