//
//  QSTextManipulationPlugIn.m
//  QSTextManipulationPlugIn
//
//  Created by Nicholas Jitkoff on 3/31/05.
//  Copyright __MyCompanyName__ 2005. All rights reserved.
//

#import "QSTextManipulationPlugIn.h"
#define kQSTextAppendAction @"QSTextAppendAction"
#define kQSTextPrependAction @"QSTextPrependAction"
#define kQSLineRefEditAction @"QSLineRefEditAction"
#define kQSLineRefDeleteAction @"QSLineRefDeleteAction"
#define kQSTextAppendReverseAction @"QSTextAppendReverseAction"
#define kQSTextPrependReverseAction @"QSTextPrependReverseAction"
#define kQSTextAppendTimedAction @"QSTextAppendTimedAction"
#define kQSTextPrependTimedAction @"QSTextPrependTimedAction"
#define kQSTextAppendTimedReverseAction @"QSTextAppendTimedReverseAction"
#define kQSTextPrependTimedReverseAction @"QSTextPrependTimedReverseAction"
#define textTypes @[@"'TEXT'", @"txt", @"sh", @"pl", @"rb", @"html", @"htm",@"md",@"markdown", @"mdown", @"mkdn"]
#define richTextTypes @[@"rtf", @"doc", @"rtfd"]

@implementation QSTextManipulationPlugIn

- (id)init
{
    self = [super init];
    if (self) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        _reverseActions = @[kQSTextAppendReverseAction, kQSTextPrependReverseAction, kQSTextAppendTimedReverseAction, kQSTextPrependTimedReverseAction];
    }
    return self;
}

- (NSArray *)validIndirectObjectsForAction:(NSString *)action directObject:(QSObject *)dObject {
    
    // for the Change To... select the current line to be changed
	if ([action isEqualToString:kQSLineRefEditAction]) {
        return [NSArray arrayWithObject:[QSObject textProxyObjectWithDefaultValue:[dObject stringValue]]]; 
    } else {
        if ([self.reverseActions containsObject:action]) {
            return @[[QSObject textProxyObjectWithDefaultValue:@""]];
        }
    }
    return nil;
}

- (NSArray *)validActionsForDirectObject:(QSObject *)dObject indirectObject:(QSObject *)iObject {
    // most methods are only set to work for 1 direct object
    if ([dObject count] == 1) {
        
        return [self.reverseActions arrayByAddingObjectsFromArray:@[kQSLineRefEditAction, kQSLineRefDeleteAction]];
        
        // In the future, we may wish to make the Append Text... and Prepend Text... actions available for ALL files of type text
        
        /* NSArray *validActions;
        NSString *type = [[NSFileManager defaultManager] UTIOfFile:[dObject singleFilePath]];
        if (UTTypeConformsTo((CFStringRef)type, kUTTypeText)) {
            validActions = [NSArray arrayWithObjects:kQSTextAppendReverseAction,kQSTextPrependReverseAction,kQSLineRefEditAction,kQSLineRefDeleteAction,nil];
        } else {
                 validActions = [NSArray arrayWithObjects:kQSLineRefDeleteAction,kQSLineRefEditAction,nil];

             }
        return validActions; */
         
    }
    return nil;
}

- (QSObject *)prependObject:(QSObject *)dObject toObject:(QSObject *)iObject {
    return [self appendObject:(QSObject *)dObject toObject:(QSObject *)iObject withTimestamp:NO atBeginning:YES];
}
- (QSObject *)appendObject:(QSObject *)dObject toObject:(QSObject *)iObject {
    return [self appendObject:(QSObject *)dObject toObject:(QSObject *)iObject withTimestamp:NO atBeginning:NO];
    
}

- (QSObject *)prependTimestampedObject:(QSObject *)dObject toObject:(QSObject *)iObject
{
    return [self appendObject:(QSObject *)dObject toObject:(QSObject *)iObject withTimestamp:YES atBeginning:YES];
}

- (QSObject *)appendTimestampedObject:(QSObject *)dObject toObject:(QSObject *)iObject {
    return [self appendObject:(QSObject *)dObject toObject:(QSObject *)iObject withTimestamp:YES atBeginning:NO];
}

- (QSObject *)appendObject:(QSObject *)dObject toObject:(QSObject *)iObject withTimestamp:(BOOL)includeTime atBeginning:(BOOL)atBeginning
{
	NSString *newLine = nil;
    NSString *timestamp = includeTime ? [self.dateFormatter stringFromDate:[NSDate date]] : nil;
    for (QSObject *anObject in [dObject splitObjects]) {
        // get the new line - file path for files or text (else string value - last case)
        if ([[anObject primaryType] isEqualToString:QSFilePathType]) {
            newLine = [[anObject singleFilePath] stringByAbbreviatingWithTildeInPath];
        } else if([[anObject primaryType] isEqualToString:QSTextType]) {
            newLine = [anObject objectForType:QSTextType];
        } else {
            newLine = [anObject stringValue];
        }
        
        // prepend a timestamp?
        if (includeTime) {
            newLine = [NSString stringWithFormat:@"%@ %@", timestamp, newLine];
        }
        
        // if we're within a file (QSLineReferenceType file)
        if ([iObject containsType:@"QSLineReferenceType"]) {
            
            NSDictionary *reference = [iObject objectForType:@"QSLineReferenceType"];
            NSString *file = [[reference objectForKey:@"path"] stringByStandardizingPath];
            NSStringEncoding encoding;

            NSString *string = [NSString stringWithContentsOfFile:file usedEncoding:&encoding error:nil];
            NSMutableArray *lines = [[string lines] mutableCopy];
            NSUInteger lineIndex = [[reference objectForKey:@"line"] unsignedIntegerValue];
            if (atBeginning) {
                lineIndex--;
            }
            [lines insertObject:newLine atIndex:lineIndex];
            
            [[lines componentsJoinedByString:@"\n"] writeToFile:file atomically:NO encoding:encoding error:nil];
        } else {
            NSString *path = [iObject singleFilePath];
            NSString *type = [[NSFileManager defaultManager] typeOfFile:path];
            
            // rich text
        if (UTTypeConformsTo((__bridge CFStringRef)[iObject fileUTI], (__bridge CFStringRef)@"public.rtf") || [richTextTypes containsObject:type]) {
                NSDictionary *docAttributes = nil;
                NSError *error = nil;
                NSMutableAttributedString *astring = [[NSMutableAttributedString alloc] initWithURL:[NSURL fileURLWithPath:path]
                                                                                            options:nil
                                                                                 documentAttributes:&docAttributes
                                                                                              error:&error];
                NSDictionary *attributes = [astring attributesAtIndex:atBeginning ? 0 : [astring length]-1
                                                       effectiveRange:nil];
                NSAttributedString *newlineString = [[NSAttributedString alloc] initWithString:@"\n" attributes:attributes];
                NSAttributedString *appendString = [[NSAttributedString alloc] initWithString:newLine  attributes:attributes];
                
                if (atBeginning) {
                    [astring insertAttributedString:newlineString atIndex:0];
                    [astring insertAttributedString:appendString atIndex:0];
                } else {
                    unichar lastChar = [[astring string] characterAtIndex:[astring length] - 1];
                    BOOL newlineAtEnd = lastChar == '\r' || lastChar == '\n';
                    if (!newlineAtEnd) [astring appendAttributedString:newlineString];
                    [astring appendAttributedString:appendString];
                    if (newlineAtEnd) [astring appendAttributedString:newlineString];
                }
                
                NSFileWrapper *wrapper = [astring fileWrapperFromRange:NSMakeRange(0, [astring length])
                                                    documentAttributes:docAttributes error:&error];
                
                if (!error)
                    [wrapper writeToFile:path atomically:NO updateFilenames:YES];
                
        } else if (UTTypeConformsTo((__bridge CFStringRef)[iObject fileUTI], (__bridge CFStringRef)@"public.text") || [textTypes containsObject:type]) {
                NSStringEncoding encoding;
                NSString *text = [NSString stringWithContentsOfFile:path usedEncoding:&encoding error:nil];
                if (atBeginning || ![text length]) {
                    text = [NSString stringWithFormat:@"%@\n%@", newLine , text];  
                } else {
                    unichar lastChar = [text characterAtIndex:[text length] -1];
                    BOOL newlineAtEnd = lastChar == '\r' || lastChar == '\n';
                    text = [NSString stringWithFormat:newlineAtEnd?@"%@%@\n":@"%@\n%@", text, newLine];
                }
                [text writeToFile:path atomically:NO encoding:encoding error:nil];
            } else {
                QSShowAppNotifWithAttributes(@"QSTextManipulation", NSLocalizedStringFromTableInBundle(@"Error Appending Text", nil, [NSBundle bundleForClass:[self class]], @"Title for the error notif when appending text fails"), [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Cannot append text to %@ files", nil, [NSBundle bundleForClass:[self class]], @"MEssage of the error notif when appending text fails"),type]);
            }
        }
    }
    if ([iObject containsType:@"QSLineReferenceType"]) {
        // if it's a line type, return the original file (get it from the object's 'path' key)
        return [QSObject fileObjectWithPath:[[[iObject objectForType:@"QSLineReferenceType"] objectForKey:@"path"] stringByStandardizingPath]];
    } else {
        //return the original file
        return iObject;
    }
}


- (QSObject *)deleteLineReference:(QSObject *)dObject {
    NSString *file = [[[dObject objectForType:@"QSLineReferenceType"] objectForKey:@"path"] stringByStandardizingPath];
    NSNumber *line = [[dObject objectForType:@"QSLineReferenceType"] objectForKey:@"line"];
    NSUInteger lineNum = [line unsignedIntegerValue] -1;
    
    NSStringEncoding encoding;
    NSString *string = [NSString stringWithContentsOfFile:file usedEncoding:&encoding error:nil];
    
    string = [string stringByReplacing:@"\n" with:@"\r"];
    
    NSMutableArray *lines = [[string componentsSeparatedByString:@"\r"] mutableCopy];
    
    NSString *fileLine = [lines objectAtIndex:lineNum];
    
    if ([[dObject stringValue] isEqualToString:fileLine]) {
        [lines removeObjectAtIndex:lineNum];
        [[lines componentsJoinedByString:@"\n"] writeToFile:file atomically:NO encoding:encoding error:nil];
    } else {
        NSBeep();
        QSShowNotifierWithAttributes([NSDictionary dictionaryWithObjectsAndKeys:@"QSTextManipulationNotification", QSNotifierType, [QSResourceManager imageNamed:@"com.blacktree.quicksilver"], QSNotifierIcon, @"Text Manipulation", QSNotifierTitle, @"Contents of file have changed. Line was not deleted.", QSNotifierText, nil]);
    }
    return [QSObject fileObjectWithPath:file];
}

- (QSObject *)changeLineReference:(QSObject *)dObject to:(QSObject *)iObject {
    NSString *file = [[[dObject objectForType:@"QSLineReferenceType"] objectForKey:@"path"] stringByStandardizingPath];
    NSNumber *line = [[dObject objectForType:@"QSLineReferenceType"] objectForKey:@"line"];
    NSUInteger lineNum = [line unsignedIntegerValue] -1;
    
    NSString *replacement = [iObject stringValue];
    
    NSStringEncoding encoding;
    NSString *string = [NSString stringWithContentsOfFile:file usedEncoding:&encoding error:nil];
    NSMutableArray *lines = [[string lines] mutableCopy];
    
    
    NSString *fileLine = [lines objectAtIndex:lineNum];
    if ([[dObject stringValue] isEqualToString:fileLine]) {
        [lines replaceObjectAtIndex:lineNum withObject:replacement];
        [[lines componentsJoinedByString:@"\n"] writeToFile:file atomically:NO encoding:encoding error:nil];
    } else {
        NSBeep();
        QSShowNotifierWithAttributes([NSDictionary dictionaryWithObjectsAndKeys:@"QSTextManipulationNotification", QSNotifierType, [QSResourceManager imageNamed:@"com.blacktree.quicksilver"], QSNotifierIcon, @"Text Manipulation", QSNotifierTitle, @"Contents of file have changed. Change was abandoned.", QSNotifierText, nil]);
    }
    return [QSObject fileObjectWithPath:file];
}


@end
