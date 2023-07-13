/*
 * 
 * NSDictionary+XML.h
 * softphone
 * 
 * Created by Stanislav Kutil on 2/9/10.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#include "ali/ali_xml_tree2.h"
#include "ali/ali_auto_ptr_forward.h"

@interface NSDictionary(XML) 

+(ali::auto_ptr<ali::xml::tree>) XMLFromDictionary:(NSDictionary *) dict;

@end
