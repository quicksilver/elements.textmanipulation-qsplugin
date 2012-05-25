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
#define textTypes [NSArray arrayWithObjects:@"'TEXT'", @"txt", @"sh", @"pl", @"rb", @"html", @"htm", nil]
#define richTextTypes [NSArray arrayWithObjects:@"rtf", @"doc", @"rtfd", nil]

@implementation QSTextManipulationPlugIn

- (NSArray *)validIndirectObjectsForAction:(NSString *)action directObject:(QSObject *)dObject {

    // for the Change To... select the current line to be changed
	if ([action isEqualToString:kQSLineRefEditAction]) {
        return [NSArray arrayWithObject:[QSObject textProxyObjectWithDefaultValue:[dObject stringValue]]]; 
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
    
    // get the new line - file path for files or text (else string value - last case)
    if ([[dObject primaryType] isEqualToString:QSFilePathType]) {
        newLine = [[dObject singleFilePath] stringByAbbreviatingWithTildeInPath];
    } else if([[dObject primaryType] isEqualToString:QSTextType]) {
        newLine = [dObject objectForType:QSTextType];
    } else {
        newLine = [dObject stringValue];
    }
    
    // if we're within a file (QSLineReferenceType file)
	if ([iObject containsType:@"QSLineReferenceType"]) {
		
		NSDictionary *reference = [iObject objectForType:@"QSLineReferenceType"];
		NSString *file = [[reference objectForKey:@"path"] stringByStandardizingPath];
		NSString *string = [NSString stringWithContentsOfFile:file];
		
		NSMutableArray *lines = [[[string lines] mutableCopy] autorelease]; 		
		NSUInteger lineIndex = [[reference objectForKey:@"line"] unsignedIntegerValue];
		if (atBeginning) {
            lineIndex--;
        }
		[lines insertObject:newLine atIndex:lineIndex];

		[[lines componentsJoinedByString:@"\n"] writeToFile:file atomically:NO];
		
		return [QSObject fileObjectWithPath:file];
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
			NSString *text = [NSString stringWithContentsOfFile:path];
			if (atBeginning) {
				text = [NSString stringWithFormat:@"%@\n%@", newLine , text];  
			} else {
				unichar lastChar = [text characterAtIndex:[text length] -1];
				BOOL newlineAtEnd = lastChar == '\r' || lastChar == '\n';
				text = [NSString stringWithFormat:newlineAtEnd?@"%@%@\n":@"%@\n%@", text, newLine];
			}
			[text writeToFile:path atomically:NO];
		} else {
			NSBeep();  
		}
		return iObject;
	}
}


- (QSObject *)deleteLineReference:(QSObject *)dObject {
	NSString *file = [[[dObject objectForType:@"QSLineReferenceType"] objectForKey:@"path"] stringByStandardizingPath];
	NSNumber *line = [[dObject objectForType:@"QSLineReferenceType"] objectForKey:@"line"];
	NSUInteger lineNum = [line unsignedIntegerValue] -1;
	
	NSString *string = [NSString stringWithContentsOfFile:file];
	
	string = [string stringByReplacing:@"\n" with:@"\r"];
	
	NSMutableArray *lines = [[[string componentsSeparatedByString:@"\r"] mutableCopy] autorelease];
	
	NSString *fileLine = [lines objectAtIndex:lineNum];

	if ([[dObject stringValue] isEqualToString:fileLine]) {
		[lines removeObjectAtIndex:lineNum];
		[[lines componentsJoinedByString:@"\n"] writeToFile:file atomically:NO];
	} else {
		NSBeep();
        QSShowNotifierWithAttributes([NSDictionary dictionaryWithObjectsAndKeys:@"QSTextManipulationNotification", QSNotifierType, [QSResourceManager imageNamed:@"com.blacktree.quicksilver"], QSNotifierIcon, @"Text Manipulation", QSNotifierTitle, @"Contents of file have changed. Line was not deleted.", QSNotifierText, nil]);
    }
	return nil;
}

- (QSObject *)changeLineReference:(QSObject *)dObject to:(QSObject *)iObject {
	NSString *file = [[[dObject objectForType:@"QSLineReferenceType"] objectForKey:@"path"] stringByStandardizingPath];
	NSNumber *line = [[dObject objectForType:@"QSLineReferenceType"] objectForKey:@"line"];
	NSUInteger lineNum = [line unsignedIntegerValue] -1;
	
	NSString *replacement = [iObject stringValue];
	
	NSString *string = [NSString stringWithContentsOfFile:file];
	NSMutableArray *lines = [[[string lines] mutableCopy] autorelease];
	
	
	NSString *fileLine = [lines objectAtIndex:lineNum];
	if ([[dObject stringValue] isEqualToString:fileLine]) {
		[lines replaceObjectAtIndex:lineNum withObject:replacement];
		[[lines componentsJoinedByString:@"\n"] writeToFile:file atomically:NO];
	} else {
		NSBeep();
        QSShowNotifierWithAttributes([NSDictionary dictionaryWithObjectsAndKeys:@"QSTextManipulationNotification", QSNotifierType, [QSResourceManager imageNamed:@"com.blacktree.quicksilver"], QSNotifierIcon, @"Text Manipulation", QSNotifierTitle, @"Contents of file have changed. Change was abandoned.", QSNotifierText, nil]);
	}
	return [QSObject fileObjectWithPath:file];
}


@end
