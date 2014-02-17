//
//  QSTextManipulationPlugIn.h
//  QSTextManipulationPlugIn
//
//  Created by Nicholas Jitkoff on 3/31/05.
//  Copyright __MyCompanyName__ 2005. All rights reserved.
//

#import "QSTextManipulationPlugIn.h"

@interface QSTextManipulationPlugIn : NSObject

@property (retain) NSDateFormatter *dateFormatter;
@property (retain) NSArray *reverseActions;

- (QSObject *) prependObject:(QSObject *)dObject toObject:(QSObject *)iObject;
- (QSObject *) appendObject:(QSObject *)dObject toObject:(QSObject *)iObject;
- (QSObject *) appendObject:(QSObject *)dObject toObject:(QSObject *)iObject withTimestamp:(BOOL)includeTime atBeginning:(BOOL)atBeginning;
@end

