//
//  ComposeMessageViewController.m
//  TextSecureiOS
//
//  Created by Frederic Jacobs on 10/30/13.
//  Copyright (c) 2013 Open Whisper Systems. All rights reserved.
//

#import "ComposeMessageViewController.h"
#import "TSContactManager.h"
#import "TSContact.h"

@interface ComposeMessageViewController (Private)
- (void)resizeViews;
@end

@implementation ComposeMessageViewController {
	TITokenFieldView * _tokenFieldView;
	
	CGFloat _keyboardHeight;
}

- (id) initWithConversationID:(NSString*)contactID{
    self = [super initWithNibName:nil bundle:nil];
    
    NSString *nameOfContact = @"ContactX";
    
    self.messages = [NSMutableArray array];
    
    self.timestamps = [NSMutableArray array];
    
    self.title = nameOfContact;
    
    return self;
}

- (id) initNewConversation{
    
    self = [super initWithNibName:nil bundle:nil];
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)])
        self.edgesForExtendedLayout = UIRectEdgeNone;
    
	[self.view setBackgroundColor:[UIColor whiteColor]];
	[self.navigationItem setTitle:@"New Message"];
    
    [TSContactManager getAllContactsIDs:^(NSArray *contacts) {
        _tokenFieldView.hidden = FALSE;
        
        NSMutableArray *contactNames;
        for (TSContact *contact in contacts){
            [contactNames addObject:[contact name]];
        }
        
        [_tokenFieldView setSourceArray:contactNames];
    }];
    
	_tokenFieldView = [[TITokenFieldView alloc] initWithFrame:self.view.bounds];
	[_tokenFieldView setSourceArray:nil];
    
	[_tokenFieldView.tokenField setDelegate:self];
	[_tokenFieldView.tokenField addTarget:self action:@selector(tokenFieldFrameDidChange:) forControlEvents:(UIControlEvents) TITokenFieldControlEventFrameDidChange];
	[_tokenFieldView.tokenField setTokenizingCharacters:[NSCharacterSet characterSetWithCharactersInString:@",;."]]; // Default is a comma
    [_tokenFieldView.tokenField setPromptText:@"To:"];
	[_tokenFieldView.tokenField setPlaceholder:@"Type a name"];
	
    [_tokenFieldView.tokenField addTarget:self action:@selector(tokenFieldChangedEditing:) forControlEvents:UIControlEventEditingDidBegin];
	[_tokenFieldView.tokenField addTarget:self action:@selector(tokenFieldChangedEditing:) forControlEvents:UIControlEventEditingDidEnd];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[_tokenFieldView setHidden:TRUE];
    
    [self.view addSubview:_tokenFieldView];
    
	// You can call this on either the view on the field.
	// They both do the same thing.
	[_tokenFieldView becomeFirstResponder];
    
    self.messages = [NSMutableArray array];
    self.timestamps = [NSMutableArray array];
    
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.delegate = self;
    self.dataSource = self;
    self.inputToolBarView.textView.delegate = self;

	[self.view setBackgroundColor:[UIColor whiteColor]];
    
    self.tableView.frame = CGRectMake(0, 0, self.tableView.frame.size.width, self.view.frame.size.height - 44);
    
}

- (void)keyboardWillShow:(NSNotification *)notification {
	
	CGRect keyboardRect = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	_keyboardHeight = keyboardRect.size.height > keyboardRect.size.width ? keyboardRect.size.width : keyboardRect.size.height;
	[self resizeViews];
}

- (void)keyboardWillHide:(NSNotification *)notification {
	_keyboardHeight = 0;
	[self resizeViews];
}

- (void)resizeViews {
	if (_tokenFieldView) {
        if (_keyboardHeight == 0) {
            [_tokenFieldView setFrame:((CGRect){_tokenFieldView.frame.origin, {self.view.bounds.size.width, 30.0f}})];
        } else{
            [_tokenFieldView setFrame:((CGRect){_tokenFieldView.frame.origin, {self.view.bounds.size.width, self.view.bounds.size.height - _keyboardHeight - 46.0f}})];
        }
    }
}

- (BOOL)tokenField:(TITokenField *)tokenField willRemoveToken:(TIToken *)token {
	return YES;
}

- (void)tokenFieldChangedEditing:(TITokenField *)tokenField {
	// There's some kind of annoying bug where UITextFieldViewModeWhile/UnlessEditing doesn't do anything.
	[tokenField setRightViewMode:(tokenField.editing ? UITextFieldViewModeAlways : UITextFieldViewModeNever)];
}

- (void)tokenFieldFrameDidChange:(TITokenField *)tokenField {
    
}

#pragma mark delegate methods #pragma mark - Initialization
- (UIButton *)sendButton
{
    // Override to use a custom send button
    // The button's frame is set automatically for you
    
    return [UIButton defaultSendButton];
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.messages.count;
}

#pragma mark - Messages view delegate
- (void)sendPressed:(UIButton *)sender withText:(NSString *)text
{
    
    // We remove the token field because we don't want the user to be able to edit the receipients list again
    
    if (_tokenFieldView) {
        [_tokenFieldView removeFromSuperview];
        self.title = [NSString stringWithFormat:@"%@", [_tokenFieldView.tokenField.tokenTitles objectAtIndex:0]];
        _tokenFieldView = nil;
    }
    
    [self.messages addObject:text];
    
    [self.timestamps addObject:[NSDate date]];
    
    if((self.messages.count - 1) % 2)
        [JSMessageSoundEffect playMessageSentSound];
    else
        [JSMessageSoundEffect playMessageReceivedSound];
    
    [self finishSend];
}

- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.row % 2) ? JSBubbleMessageTypeIncoming : JSBubbleMessageTypeOutgoing;
}

- (JSBubbleMessageStyle)messageStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return JSBubbleMessageStyleFlat;
}

- (JSMessagesViewTimestampPolicy)timestampPolicy
{
    return JSMessagesViewTimestampPolicyEveryThree;
}

- (JSMessagesViewAvatarPolicy)avatarPolicy
{
    return JSMessagesViewAvatarPolicyNone;
}

- (JSAvatarStyle)avatarStyle
{
    return JSAvatarStyleSquare;
}

- (JSInputBarStyle)inputBarStyle
{
    return JSInputBarStyleFlat;
}

#pragma mark - Messages view data source
- (NSString *)textForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.messages objectAtIndex:indexPath.row];
}

- (NSDate *)timestampForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.timestamps objectAtIndex:indexPath.row];
}

- (UIImage *)avatarImageForIncomingMessage{
    return nil;
}

- (UIImage *)avatarImageForOutgoingMessage{
    return nil;
}

#pragma mark UITextViewDelegate (Sending box)

-(BOOL)textViewShouldBeginEditing:(UITextView *)textView{
    
    if ([textView isEqual:self.inputToolBarView.textView]) {
        
        self.tableView.frame = CGRectMake(0, 0, self.tableView.frame.size.width, self.view.frame.size.height - 44);
        
        // We start editing the message field, proceed to UI changes.
        if (_tokenFieldView) {
            [self startedWritingMessage];
        }
    }
    
    return true;
}

-(void) startedWritingMessage{
    // Change frames for editing
    
    if (_tokenFieldView) {
        [_tokenFieldView setScrollEnabled:FALSE];
         _tokenFieldView.frame = CGRectMake(_tokenFieldView.frame.origin.x, _tokenFieldView.frame.origin.y, _tokenFieldView.frame.size.width, 43);
        self.tableView.frame = CGRectMake(0, 44, self.tableView.frame.size.width, self.tableView.frame.size.height);
        _tokenFieldView.contentSize = CGSizeMake(_tokenFieldView.frame.size.width, 43);
    }
}

-(void) startedEditingReceipients{
    //change frames for 
}

@end