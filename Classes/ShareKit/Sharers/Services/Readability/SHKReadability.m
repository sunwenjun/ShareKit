//
//  SHKReadability.m
//  ShareKit
//
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//


#import "SHKConfiguration.h"
#import "SHKReadability.h"
#import "JSONKit.h"
#import "NSMutableDictionary+NSNullsToEmptyStrings.h"

static NSString *const kSHKReadabilityUserInfo=@"kSHKReadabilityUserInfo";

@interface SHKReadability ()

- (BOOL)prepareItem;
- (BOOL)validateItemAfterUserEdit;
- (void)handleUnsuccessfulTicket:(NSData *)data;

@end

@implementation SHKReadability

@synthesize xAuth;

- (id)init
{
	if (self = [super init])
	{	
		// OAUTH		
		self.consumerKey = SHKCONFIG(readabilityConsumerKey);		
		self.secretKey = SHKCONFIG(readabilitySecret);
 		self.authorizeCallbackURL = [NSURL URLWithString:@""];
		
		// XAUTH
		self.xAuth = [SHKCONFIG(readabilityUseXAuth) boolValue]?YES:NO;
		
		
		// -- //
		
		
		// You do not need to edit these, they are the same for everyone
		self.authorizeURL = [NSURL URLWithString:@"https://www.readability.com/api/rest/v1/oauth/authorize/"];
		self.requestURL = [NSURL URLWithString:@"https://www.readability.com/api/rest/v1/oauth/request_token/"];
		self.accessURL = [NSURL URLWithString:@"https://www.readability.com/api/rest/v1/oauth/access_token/"]; 
	}	
	return self;
}


#pragma mark -
#pragma mark Configuration : Service Defination

+ (NSString *)sharerTitle
{
	return @"Readability";
}

+ (BOOL)canShareURL
{
	return YES;
}

+ (BOOL)canShareText
{
	return NO;
}

+ (BOOL)canShareImage
{
	return NO;
}

+ (BOOL)canGetUserInfo
{
	return NO;
}

#pragma mark -
#pragma mark Configuration : Dynamic Enable

- (BOOL)shouldAutoShare
{
	return NO;
}

#pragma mark -
#pragma mark Commit Share

- (void)share {
	
	BOOL itemPrepared = [self prepareItem];
	
	//the only case item is not prepared is when we wait for URL to be shortened on background thread. In this case [super share] is called in callback method
	if (itemPrepared) {
		[super share];
	}
}

- (BOOL)prepareItem {
	
	BOOL result = YES;
	
	if (item.shareType == SHKShareTypeURL)
	{
    [item setCustomValue:[item.URL absoluteString] forKey:@"url"];		
	}
	return result;
}

#pragma mark -
#pragma mark Authorization

- (BOOL)isAuthorized
{		
	return [self restoreAccessToken];
}

- (void)promptAuthorization
{	
	
	if (xAuth)
		[super authorizationFormShow]; // xAuth process
	
	else
		[super promptAuthorization]; // OAuth process		
}

+ (void)logout {
	
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kSHKReadabilityUserInfo];
	[super logout];    
}

#pragma mark xAuth

+ (NSString *)authorizationFormCaption
{
	return SHKLocalizedString(@"Create a free account at %@", @"Readability.com");
}

+ (NSArray *)authorizationFormFields
{
	
	return [NSArray arrayWithObjects:
			  [SHKFormFieldSettings label:SHKLocalizedString(@"Username") key:@"username" type:SHKFormFieldTypeTextNoCorrect start:nil],
			  [SHKFormFieldSettings label:SHKLocalizedString(@"Password") key:@"password" type:SHKFormFieldTypePassword start:nil],
			  nil];
}

- (void)authorizationFormValidate:(SHKFormController *)form
{
	self.pendingForm = form;
	[self tokenAccess];
}

- (void)tokenAccessModifyRequest:(OAMutableURLRequest *)oRequest
{	
	if (xAuth)
	{
		NSDictionary *formValues = [pendingForm formValues];
		
		OARequestParameter *username = [[[OARequestParameter alloc] initWithName:@"x_auth_username"
																								 value:[formValues objectForKey:@"username"]] autorelease];
		
		OARequestParameter *password = [[[OARequestParameter alloc] initWithName:@"x_auth_password"
																								 value:[formValues objectForKey:@"password"]] autorelease];
		
		OARequestParameter *mode = [[[OARequestParameter alloc] initWithName:@"x_auth_mode"
																							value:@"client_auth"] autorelease];
		
		[oRequest setParameters:[NSArray arrayWithObjects:username, password, mode, nil]];
	}
}

- (void)tokenAccessTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data 
{
	if (xAuth) 
	{
		if (ticket.didSucceed)
		{
			[pendingForm close];
		}
		
		else
		{
			NSString *response = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
			
			SHKLog(@"tokenAccessTicket Response Body: %@", response);
			
			[self tokenAccessTicket:ticket didFailWithError:[SHK error:response]];
			return;
		}
	}
	
	[super tokenAccessTicket:ticket didFinishWithData:data];		
}


#pragma mark -
#pragma mark UI Implementation

- (void)show
{
	if (item.shareType == SHKShareTypeURL)
	{
		[self showReadabilityForm];
	}
}

- (void)showReadabilityForm
{
	SHKFormControllerLargeTextField *rootView = [[SHKFormControllerLargeTextField alloc] initWithNibName:nil bundle:nil delegate:self];	
	
	rootView.text = [item customValueForKey:@"url"];
	rootView.maxTextLength = 1000;
	
	self.navigationBar.tintColor = SHKCONFIG_WITH_ARGUMENT(barTintForView:,self);
	
	[self pushViewController:rootView animated:NO];
	[rootView release];
	
	[[SHK currentHelper] showViewController:self];	
}

- (void)sendForm:(SHKFormControllerLargeTextField *)form
{	
	[item setCustomValue:form.textView.text forKey:@"url"];
	[self tryToSend];
}

#pragma mark -
#pragma mark Share API Methods

- (BOOL)validateItem
{
	if (self.item.shareType == SHKShareTypeURL) {
		return YES;
	}
	
	NSString *url = [item customValueForKey:@"url"];
	return url != nil;
}

- (BOOL)validateItemAfterUserEdit {
	
	BOOL result = NO;
	
	BOOL isValid = [self validateItem];    
	
	if (isValid) {
		result = YES;
	}
	
	return result;
}

- (BOOL)send
{	
	
	if (![self validateItemAfterUserEdit])
		return NO;
	
	switch (item.shareType) {
			
		case SHKShareTypeURL:            
			[self sendBookmark];
			break;
			
		default:
			[self sendBookmark];
			break;
	}
	
	// Notify delegate
	[self sendDidStart];	
	
	return YES;
}

- (void)sendBookmark
{
	OAMutableURLRequest *oRequest = [[OAMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://www.readability.com/api/rest/v1/bookmarks/"]
                                                                  consumer:consumer // this is a consumer object already made available to us
                                                                     token:accessToken // this is our accessToken already made available to us
                                                                     realm:nil
                                                         signatureProvider:signatureProvider];
	
	[oRequest setHTTPMethod:@"POST"];
	
	OARequestParameter *bookmarkParam = [[OARequestParameter alloc] initWithName:@"url"
																								value:[item customValueForKey:@"url"]];
	NSArray *params = [NSArray arrayWithObjects:bookmarkParam, nil];
	[oRequest setParameters:params];
	[bookmarkParam release];
	
	OAAsynchronousDataFetcher *fetcher = [OAAsynchronousDataFetcher asynchronousFetcherWithRequest:oRequest
																													  delegate:self
																										  didFinishSelector:@selector(sendBookmarkTicket:didFinishWithData:)
																											 didFailSelector:@selector(sendBookmarkTicket:didFailWithError:)];	
	
	[fetcher start];
	[oRequest release];
}

- (void)sendBookmarkTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data 
{	
	// TODO better error handling here
	
	if (ticket.didSucceed) 
		[self sendDidFinish];
	
	else
	{		
		[self handleUnsuccessfulTicket:data];
	}
}

- (void)sendBookmarkTicket:(OAServiceTicket *)ticket didFailWithError:(NSError*)error
{
	[self sendDidFailWithError:error];
}

#pragma mark -

- (void)handleUnsuccessfulTicket:(NSData *)data
{
	if (SHKDebugShowLogs)
		SHKLog(@"Readability Send Bookmark Error: %@", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
	
	// CREDIT: Oliver Drobnik
	
	NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];		
	
	// in case our makeshift parsing does not yield an error message
	NSString *errorMessage = @"Unknown Error";		
	
	NSScanner *scanner = [NSScanner scannerWithString:string];
	
	// skip until error message
	[scanner scanUpToString:@"\"error\":\"" intoString:nil];
	
	
	if ([scanner scanString:@"\"error\":\"" intoString:nil])
	{
		// get the message until the closing double quotes
		[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\""] intoString:&errorMessage];
	}
	
	
	// this is the error message for revoked access ...?... || removed app from Twitter
	if ([errorMessage isEqualToString:@"Invalid / used nonce"] || [errorMessage isEqualToString:@"Could not authenticate with OAuth."]) {
		
		[self shouldReloginWithPendingAction:SHKPendingSend];
		
	}
	
	NSError *error = [NSError errorWithDomain:@"Readability" code:2 userInfo:[NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey]];
	[self sendDidFailWithError:error];
}

@end
