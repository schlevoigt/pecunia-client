/**
 * Copyright (c) 2008, 2012, Pecunia Project. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of the
 * License.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301  USA
 */

#import "NewBankUserController.h"
#import "ABController.h"
#import "BankUser.h"
#import "BankingController.h"
#import "InstitutesController.h"
#import "HBCIClient.h"
#import "PecuniaError.h"
#import "LogController.h"
#import "BankParameter.h"
#import "BankInfo.h"
#import "BankAccount.h"
#import "MOAssistant.h"
#import "BankSetupInfo.h"

#import "AnimationHelper.h"
#import "BWGradientBox.h"

@interface NewBankUserController (Private)

- (void)readBanks;
- (BOOL)check;
- (void)prepareUserSheet;

@end

@implementation NewBankUserController

- (id)initForController: (BankingController*)con
{
	self = [super initWithWindowNibName:@"BankUser"];
	bankController = con;
	bankUsers = [[BankUser allUsers ] mutableCopy];
	context = [[MOAssistant assistant ] context ];
	[self readBanks];
	return self;
}

- (void)dealloc
{
	[bankUsers release];
    [institutesController release];
	[banks release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[hbciVersions setContent:[[HBCIClient hbciClient] supportedVersions]];
	[hbciVersions setSelectedObjects:[NSArray arrayWithObject:@"220"]];
    
    // Manually set up properties which cannot be set via user defined runtime attributes (Color is not available pre XCode 4).
    topGradient.fillStartingColor = [NSColor colorWithCalibratedWhite: 59 / 255.0 alpha: 1];
    topGradient.fillEndingColor = [NSColor colorWithCalibratedWhite: 99 / 255.0 alpha: 1];
    backgroundGradient.fillColor = [NSColor whiteColor];
}

#pragma mark -
#pragma mark Data handling

- (void)readBanks
{
	banks = [[NSMutableArray arrayWithCapacity: 5000] retain];
	
	NSString *path = [[NSBundle mainBundle] resourcePath];
	path = [path stringByAppendingString: @"/Institute.csv"];
	
	NSError *error=nil;
	NSString *s = [NSString stringWithContentsOfFile: path encoding:NSUTF8StringEncoding error: &error];
	if(error) {
        [[MessageLog log ] addMessage:@"Error reading institutes file" withLevel:LogLevel_Error];
	} else {
		NSArray *institutes = [s componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
		NSArray *keys = [NSArray arrayWithObjects: @"bankCode", @"bankName", @"bankLocation", @"hbciVersion", @"bankURL", nil];
		for(s in institutes) {
			NSArray *objs = [s componentsSeparatedByCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @"\t"]];
			if ([objs count] != 5) continue;
			NSDictionary *dict = [NSDictionary dictionaryWithObjects: objs forKeys: keys];
			[banks addObject: dict];
		}
	}
}

-(BankUser*)selectedUser
{
	NSArray	*selection = [bankUserController selectedObjects];
	if (selection == nil || [selection count] < 1) {
        return nil;
    }
	return [selection lastObject];
}

#pragma mark -
#pragma mark Window/sheet handling

- (void)bankUrlSheetDidEnd: (NSWindow*)sheet
                returnCode: (int)code 
               contextInfo: (void*)context
{
    /*
	int result = [NSApp runModalForWindow: [controller window]];
	if(result == 0) {
		NSDictionary *dict = [controller selectedBank];
		if(dict) {
			[currentUser setBankURL: [dict valueForKey: @"bankURL"]];
			// HBCI version
			currentUser.hbciVersion = hbciVersionFromString([dict valueForKey: @"hbciVersion"]);
		}
	}
	[[self window] makeKeyAndOrderFront: self];
     */
    
}

- (void)userSheetDidEnd: (NSWindow*)sheet
			 returnCode: (int)code 
			contextInfo: (void*)context
{
	if(code != 0) {
        [currentUserController remove:self ];
    }
}

-(void)getBankSetupInfo
{
    BankUser *currentUser = [currentUserController content ];

    BankSetupInfo *info = [[HBCIClient hbciClient ] getBankSetupInfo:currentUser.bankCode ];
    if (info != nil) {
        if (info.info_userid) {
            NSTextField *field = [[groupBox contentView ] viewWithTag:100];
            [field setStringValue:info.info_userid ];
        }
        if (info.info_customerid) {
            NSTextField *field = [[groupBox contentView ] viewWithTag:120];
            [field setStringValue:info.info_customerid ];
        }
    }
    NSView *view = [[groupBox contentView ] viewWithTag:20];
    [view setHidden:YES ];
    [progressIndicator stopAnimation: self ];
    step = 2;
    view = [[groupBox contentView ] viewWithTag:110];
    [userSheet makeFirstResponder:view ];
    
    [self prepareUserSheet ];
}

- (void)ok:(id)sender
{
    [currentUserController commitEditing ];
    if ([self check ] == NO) return;
    
    BankUser *currentUser = [currentUserController content ];
    
    if (step == 1) {
        [progressIndicator setUsesThreadedAnimation: YES];
        [progressIndicator startAnimation: self];
        NSView *view = [[groupBox contentView ] viewWithTag:20];
        [view setHidden:NO ];
        [self performSelector:@selector(getBankSetupInfo) withObject:nil afterDelay:0 ];
        return;
    }

    if (step == 2) {
        // jetzt schauen, ob wir Infos �ber die Bank haben
        BankInfo *bi = [[HBCIClient hbciClient] infoForBankCode: currentUser.bankCode inCountry: @"DE"];
        if (bi) {
            currentUser.hbciVersion = bi.pinTanVersion;
            currentUser.bankURL = bi.pinTanURL;
        }
    }

    if (step >= 2 && currentUser.hbciVersion != nil && currentUser.bankURL != nil) {
        // User anlegen
        PecuniaError *error = [[HBCIClient hbciClient ] addBankUser: currentUser];
        if (error) {
            [error alertPanel];
        }
        else {
            [bankUserController addObject:currentUser];
            [bankController updateBankAccounts: [[HBCIClient hbciClient ] getAccountsForUser:currentUser]];
            
            [userSheet orderOut: sender];
            [NSApp endSheet: userSheet returnCode: 0];
        }
    }
    
    if (step < 4) {
		step += 1;
	}
	[self prepareUserSheet ];
}

- (void)cancelSheet:(id)sender
{
	[userSheet orderOut: sender];
	[NSApp endSheet: userSheet returnCode: 1];
}

- (void)endSheet: (id)sender
{
	[currentUserController commitEditing];
	if([self check] == NO) return;
	[userSheet orderOut: sender];
	[NSApp endSheet: userSheet returnCode: 0];
}

- (BOOL)windowShouldClose:(id)sender
{
	[NSApp stopModalWithCode: 1];
	return YES;
}

#pragma mark -
#pragma mark Input handling

- (BOOL)check
{
    BankUser *currentUser = [currentUserController content ];

    if (step == 1) {
        if (currentUser.bankCode == nil) {
            NSRunAlertPanel(NSLocalizedString(@"AP1", @"Missing data"),
                            NSLocalizedString(@"AP2", @"Please enter bank code"),
                            NSLocalizedString(@"ok", @"Ok"), nil, nil);
            return NO;
        }
        if (currentUser.name == nil) {
            NSRunAlertPanel(NSLocalizedString(@"AP1", @"Missing data"),
                            NSLocalizedString(@"AP176", @"Please enter name"),
                            NSLocalizedString(@"ok", @"Ok"), nil, nil);
            return NO;
        }
    }
    
    
    if (step == 2) {
        if ([currentUser userId] == nil) {
            NSRunAlertPanel(NSLocalizedString(@"AP1", @"Missing data"),
                            NSLocalizedString(@"AP3", @"Please enter user id"),
                            NSLocalizedString(@"ok", @"Ok"), nil, nil);
            return NO;
        }
    }
    /*
	if ([currentUser bankURL] == nil) {
		NSRunAlertPanel(NSLocalizedString(@"AP1", @"Missing data"), 
						NSLocalizedString(@"AP6", @"Please enter bank server URL"),
						NSLocalizedString(@"ok", @"Ok"), nil, nil);
		return NO;
	}
     */
	return YES;
}

-(void)controlTextDidChange:(NSNotification *)aNotification
{
	NSTextField	*te = [aNotification object];
	NSString *s = [te stringValue];
    BankUser *currentUser = [currentUserController content ];
    
    if ([te tag ] == 10) {
        NSString *bankCode = [s stringByReplacingOccurrencesOfString:@" " withString:@"" ];
        if ([bankCode length ] == 8) {
            BankInfo *bi = [[HBCIClient hbciClient] infoForBankCode: bankCode inCountry: @"DE"];
            if (bi) {
                currentUser.name = bi.name;
                [okButton setKeyEquivalent:@"\r" ];
            }
        }
    }
}

-(void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	NSTextField	*te = [aNotification object];
	NSString *bankCode = [te stringValue];
    BankUser *currentUser = [currentUserController content ];
    
	BankInfo *bi = [[HBCIClient hbciClient] infoForBankCode: bankCode inCountry: @"DE"];
	if (bi) {
        currentUser.bankName = bi.name;
        currentUser.bankURL = bi.pinTanURL;
        currentUser.hbciVersion = bi.pinTanVersion;
	}
}

#pragma mark -
#pragma mark IB action section

- (IBAction)close:(id)sender
{
    [[self window] orderOut: self];
}

- (IBAction)add:(id)sender
{
	[[self window] close];
}

- (IBAction)allSettings:(id)sender
{
    if (step > 3) return;
    
    BankUser *currentUser = [currentUserController content ];
    if (currentUser.hbciVersion == nil) currentUser.hbciVersion = @"220";
    
	NSArray *views = [[groupBox contentView ] subviews ];
    for(NSView *view in views) {
        if ([view tag ] >= 100) {
            [[view animator] setHidden:NO ];
        }
    }
    
    NSRect frame = [userSheet frame ];
    if(step == 2)  {
        frame.size.height += 119; frame.origin.y -= 119;
    } else {
        frame.size.height += 183; frame.origin.y -= 183;
    }
    [[userSheet animator] setFrame: frame display: YES ];
    
    
    step = 4;
}

- (void)prepareUserSheet
{
	NSArray *views = [[groupBox contentView ] subviews ];
	
	if (step == 1) {
		for(NSView *view in views) {
			if ([view tag ] >= 100) {
				[view setHidden:YES ];
			}
		}
        
		NSRect frame = [userSheet frame ];
		frame.size.height = 406;
		frame.size.height -= 183; frame.origin.y += 183;
		[userSheet setFrame: frame display: YES ];
	}
	if (step == 2) {
		for(NSView *view in views) {
			if ([view tag ] >= 100 && [view tag ] <= 130) {
				[[view animator] setHidden:NO ];
			}
		}

		NSRect frame = [userSheet frame ];
		frame.size.height += 64; frame.origin.y -= 64;
		[[userSheet animator] setFrame: frame display: YES ];
	}
	if (step == 3) {
		for(NSView *view in views) {
			if ([view tag ] > 130) {
				[[view animator] setHidden:NO ];
			}
		}
        
		NSRect frame = [userSheet frame ];
		frame.size.height += 119; frame.origin.y -= 119;
		[[userSheet animator] setFrame: frame display: YES ];
	}			
}

- (IBAction)addEntry:(id)sender
{
    [currentUserController add:self ];
	
	step = 1;
	[self prepareUserSheet ];
    
	[NSApp beginSheet: userSheet
	   modalForWindow: [self window ]
		modalDelegate: self
	   didEndSelector: @selector(userSheetDidEnd:returnCode:contextInfo:)
		  contextInfo: NULL ];
}

- (IBAction)selectBankUrl: (id)sender
{
    if (selectBankUrlSheet == nil) {
        institutesController = [[InstitutesController alloc] init];
        [institutesController setBankData: banks];
        selectBankUrlSheet = [institutesController window];
    }
    
	[NSApp beginSheet: selectBankUrlSheet
	   modalForWindow: [self window]
		modalDelegate: self
	   didEndSelector: @selector(bankUrlSheetDidEnd:returnCode:contextInfo:)
		  contextInfo: NULL];

}

- (IBAction)removeEntry:(id)sender
{
	BankUser* user = [self selectedUser];
	if (user == nil) return;
	
	if([[HBCIClient hbciClient] deleteBankUser: user] == TRUE) {
        // remove userId from all related bank accounts
        NSError *error=nil;
        NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"BankAccount" inManagedObjectContext:context];
        NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
        [request setEntity:entityDescription];
        NSPredicate *predicate = [NSPredicate predicateWithFormat: @"bankCode = %@ AND userId = %@", user.bankCode, user.userId];
        [request setPredicate:predicate];
        NSArray *accounts = [context executeFetchRequest:request error:&error];
        if (error == nil) {
            for (BankAccount *account in accounts) {
                account.userId = nil;
                account.customerId = nil;
            }
        }
		[bankUserController remove: self];
	}
}

- (IBAction)getUserAccounts: (id)sender
{
	BankUser *user = [self selectedUser];
	if(user == nil) return;

	[bankController updateBankAccounts: [[HBCIClient hbciClient] getAccountsForUser:user]];

	NSRunAlertPanel(NSLocalizedString(@"AP27", @""),
					NSLocalizedString(@"AP107", @""),
					NSLocalizedString(@"ok", @"Ok"), 
					nil, nil,
					user.userId);
	
}

-(IBAction)changePinTanMethod:(id)sender
{
	BankUser *user = [self selectedUser];
	if(user == nil) return;
	 PecuniaError *error = [[HBCIClient hbciClient] changePinTanMethodForUser:user];
	if (error) {
		[error alertPanel];
	}
}

-(IBAction)printBankParameter:(id)sender
{
	BankUser *user = [self selectedUser];
	if (user == nil) return;
	LogController *logController = [LogController logController];
	MessageLog *messageLog = [MessageLog log];
//	[[logController window] makeKeyAndOrderFront:self];
	[logController showWindow:self];
	[logController setLogLevel:LogLevel_Info];
	BankParameter *bp = [[HBCIClient hbciClient] getBankParameterForUser: user];
	if (bp == nil) {
		[messageLog addMessage:@"Bankparameter konnten nicht ermittelt werden" withLevel:LogLevel_Error];
		return;
	}
	[messageLog addMessage:@"Bankparameterdaten:" withLevel:LogLevel_Info];
    [messageLog addMessage: bp.bpd_raw withLevel:LogLevel_Notice];
    
	[messageLog addMessage:@"Anwenderparameterdaten:" withLevel:LogLevel_Info];
    [messageLog addMessage: bp.upd_raw withLevel:LogLevel_Notice];
}


- (IBAction)updateBankParameter: (id)sender
{
	BankUser *user = [self selectedUser];
	if(user == nil) return;
	
	PecuniaError *error = [[HBCIClient hbciClient] updateBankDataForUser: user];
	if(error) [error alertPanel];
	else NSRunAlertPanel(NSLocalizedString(@"AP27", @"Success"), 
						 NSLocalizedString(@"AP28", @"Bank parameter have been updated successfully"), 
						 NSLocalizedString(@"ok", @"Ok"), nil, nil);
}

@end
