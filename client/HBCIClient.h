//
//  HBCIClient.h
//  Pecunia
//
//  Created by Frank Emminghaus on 25.11.09.
//  Copyright 2009 Frank Emminghaus. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Transfer.h"
#import "LogLevel.h"
#import "StandingOrder.h"

@class HBCIBridge;
@class BankInfo;
@class ABUser;
@class PecuniaError;
@class BankAccount;
@class Account;
@class ABController;
@class TransactionLimits;

@interface HBCIClient : NSObject {
//	HBCIBridge		*bridge;
	ABController	*bridge;
	
	NSMutableArray		*passports;
	NSMutableArray		*accounts;
	NSMutableDictionary	*bankInfo;
	NSMutableDictionary *countryInfos;
	NSArray				*bankQueryResults;
	int					currentQuery;
	id					asyncCommandSender;
}

-(void)readCountryInfos;
-(NSDictionary*)countryInfos;


-(NSArray*)initHBCI;
-(NSArray*)accounts;
-(NSArray*)users;

// HBCI Methods
-(BankInfo*)infoForBankCode: (NSString*)bankCode inCountry:(NSString*)country;
-(NSString*)bankNameForCode:(NSString*)bankCode inCountry:(NSString*)country;
-(NSString*)bankNameForBIC:(NSString*)bic inCountry:(NSString*)country;
-(void)getStatements:(NSArray*)resultList;
-(void)getStandingOrders:(NSArray*)accounts;
-(BOOL)checkAccount: (NSString*)accountNumber forBank: (NSString*)bankCode inCountry: (NSString*)country;
-(BOOL)checkIBAN: (NSString*)iban;
-(void)asyncCommandCompletedWithResult:(id)result error:(PecuniaError*)err;
-(BOOL)isTransferSupported:(TransferType)tt forAccount:(BankAccount*)account;
-(BOOL)isStandingOrderSupportedForAccount:(BankAccount*)account;
-(BOOL)sendTransfers:(NSArray*)transfers;
-(NSArray*)allowedCountriesForAccount:(BankAccount*)account;
-(NSDictionary*)allCountries;
-(TransactionLimits*)limitsForType:(TransferType)tt account:(BankAccount*)account country:(NSString*)ctry;
-(TransactionLimits*)standingOrderLimitsForAccount:(BankAccount*)account action:(StandingOrderAction)action;
-(BOOL)updateStandingOrders:(NSArray*)orders;

-(BOOL)addAccount: (BankAccount*)account forUser: (ABUser*)user;

-(void)startLog:(id <MessageLog>)logger withLevel:(LogLevel)level withDetails:(BOOL)details;
-(void)endLog;

-(NSString*)addBankUser:(ABUser*)user;
-(BOOL)removeBankUser:(ABUser*)user;
-(NSString*)getSystemIDForUser:(ABUser*)user;

+(HBCIClient*)hbciClient;

@end