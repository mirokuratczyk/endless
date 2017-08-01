/*
 * Copyright (c) 2017, Psiphon Inc.
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


#import "DownloadHelper.h"

#define kDownloadsDirectory @"downloads"

@implementation DownloadHelper {
}

#pragma mark - helper functions

+ (NSString*)getDownloadsDirectory {
	NSString *downloadsPath = [NSTemporaryDirectory() stringByAppendingPathComponent:kDownloadsDirectory];

	// Clear directory on the first download of this session
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[[NSFileManager defaultManager] removeItemAtPath:downloadsPath error:nil];
	});

	BOOL isDirectory = YES;
	if (![[NSFileManager defaultManager] fileExistsAtPath:downloadsPath isDirectory:&isDirectory]) {
		NSError *err;
		// Create temp folder for downloads
		[[NSFileManager defaultManager] createDirectoryAtPath:downloadsPath withIntermediateDirectories:NO attributes:nil error:&err];
		if (err != nil) {
#ifdef TRACE
			NSLog(@"DownloadManager: failed to create downloadsPath %@ with error %@", downloadsPath, err.localizedDescription);
#endif
			return NSTemporaryDirectory(); // fallback on default temporary directory
		}
	}

	return downloadsPath;
}

+ (NSURL*)moveFileToDownloadDirectory:(NSURL*)filePath withExtension:(NSString*)extension {
	if (filePath == nil || extension ==  nil) {
#ifdef TRACE
		NSLog(@"DownloadManager: move file failed filePath was %@ and extension was %@", filePath, extension);
#endif
		return nil;
	}

	/*
	 *	If a file already exists at the new location then rename it
	 *	e.g. example.extension would be renamed to example(1).extension.
	 */
	NSURL *newLocation = [NSURL fileURLWithPath:[[DownloadHelper getDownloadsDirectory] stringByAppendingPathComponent:extension]];
	int i = 1;
	while ([[NSFileManager defaultManager] fileExistsAtPath:[newLocation path]]) {
		NSArray <NSString*> *split = [extension componentsSeparatedByString:@"."];
		newLocation = [NSURL fileURLWithPath:[[DownloadHelper getDownloadsDirectory] stringByAppendingPathComponent:[[split objectAtIndex:0] stringByAppendingString:[NSString stringWithFormat:@"(%d)", i++]]]];
		for (int i = 1; i < [split count]; i++) {
			NSString *str = [NSString stringWithFormat:@"%@.%@", [newLocation absoluteString], [split objectAtIndex:i]];
			newLocation = [NSURL URLWithString:str];
		}
	}

	NSError *err;
	[[NSFileManager defaultManager] moveItemAtURL:filePath toURL:newLocation error:&err];
	if (err != nil) {
#ifdef TRACE
		NSLog(@"DownloadManager: failed to rename file %@ to %@ with error %@", filePath, newLocation, [err localizedDescription]);
#endif
		return nil;
	}

	return newLocation;
}

@end
