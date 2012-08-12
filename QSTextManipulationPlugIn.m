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
#define textTypes [NSArray arrayWithObjects:@"'TEXT'", @"txt", @"sh", @"pl", @"rb", @"html", @"htm",@"md",@"markdown", @"mdown", @"mkdn", nil]
#define richTextTypes [NSArray arrayWithObjects:@"rtf", @"doc", @"rtfd", nil]

@implementation QSTextManipulationPlugIn

- (NSArray *)validIndirectObjectsForAction:(NSString *)action directObject:(QSObject *)dObject {
    
    // for the Change To... select the current line to be changed
	if ([action isEqualToString:kQSLineRefEditAction]) {
        return [NSArray arrayWithObject:[QSObject textProxyObjectWithDefaultValue:[dObject stringValue]]]; 
    } else if ([action isEqualToString:kQSTextAppendReverseAction] || [action isEqualToString:kQSTextPrependReverseAction]) {
        return [NSArray arrayWithObject:[QSObject textProxyObjectWithDefaultValue:@""]];
    }
    return nil;
}

- (NSArray *)validActionsForDirectObject:(QSObject *)dObject indirectObject:(QSObject *)iObject {
    // most methods are only set to work for 1 direct object
    if ([dObject count] == 1) {
        
        return [NSArray arrayWithObjects:kQSTextAppendReverseAction,kQSTextPrependReverseAction,kQSLineRefEditAction,kQSLineRefDeleteAction,nil];
        
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
    return [self appendObject:(QSObject *)dObject toObject:(QSObject *)iObject atBeginning:YES];
}
- (QSObject *)appendObject:(QSObject *)dObject toObject:(QSObject *)iObject {
    return [self appendObject:(QSObject *)dObject toObject:(QSObject *)iObject atBeginning:NO];
    
}
- (QSObject *)appendObject:(QSObject *)dObject toObject:(QSObject *)iObject atBeginning:(BOOL)atBeginning {
    
	NSString *newLine = nil;
    for (QSObject *anObject in [dObject splitObjects]) {
        // get the new line - file path for files or text (else string value - last case)
        if ([[anObject primaryType] isEqualToString:QSFilePathType]) {
            newLine = [[anObject singleFilePath] stringByAbbreviatingWithTildeInPath];
        } else if([[anObject primaryType] isEqualToString:QSTextType]) {
            newLine = [anObject objectForType:QSTextType];
        } else {
            newLine = [anObject stringValue];
        }
        
        // if we're within a file (QSLineReferenceType file)
        if ([iObject containsType:@"QSLineReferenceType"]) {
            
            NSDictionary *reference = [iObject objectForType:@"QSLineReferenceType"];
            NSString *file = [[reference objectForKey:@"path"] stringByStandardizingPath];
            NSStringEncoding encoding;

            NSString *string = [NSString stringWithContentsOfFile:file usedEncoding:&encoding error:nil];
            NSMutableArray *lines = [[[string lines] mutableCopy] autorelease]; 		
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
            if ([richTextTypes containsObject:type]) {
                NSDictionary *docAttributes = nil;
                NSError *error = nil;
                NSMutableAttributedString *astring = [[NSMutableAttributedString alloc] initWithURL:[NSURL fileURLWithPath:path]
                                                                                            options:nil
                                                                                 documentAttributes:&docAttributes
                                                                                              error:&error];
                NSDictionary *attributes = [astring attributesAtIndex:atBeginning ? 0 : [astring length]-1
                                                       effectiveRange:nil];
                NSAttributedString *newlineString = [[[NSAttributedString alloc] initWithString:@"\n" attributes:attributes] autorelease];
                NSAttributedString *appendString = [[[NSAttributedString alloc] initWithString:newLine  attributes:attributes] autorelease];
                
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
                
            } else if ([textTypes containsObject:type]) {
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
                NSBeep();  
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
    
    NSMutableArray *lines = [[[string componentsSeparatedByString:@"\r"] mutableCopy] autorelease];
    
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
    NSMutableArray *lines = [[[string lines] mutableCopy] autorelease];
    
    
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
