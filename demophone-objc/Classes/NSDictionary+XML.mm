/*
 * 
 * NSDictionary+XML.mm
 * softphone
 * 
 * Created by Stanislav Kutil on 2/9/10.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import "NSDictionary+XML.h"
#import "ali/ali_mac_str_utils.h"
#import "ali/ali_xml_tree2.h"

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
using ali::operator""_s;
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

@implementation NSDictionary(XML)

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
+(void) node: (ali::xml::tree &) node fromDictVal: (id) dictVal
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    if([dictVal isKindOfClass:[NSString class]])
    {
        node.data = ali::mac::str::from_nsstring(dictVal);
    }else if([dictVal isKindOfClass:[NSNumber class]])
    {
        node.attrs["type"_s].value = ali::c_string_const_ref{[dictVal objCType]};
        node.data = ali::mac::str::from_nsstring([dictVal stringValue]);
    }else if([dictVal isKindOfClass:[NSArray class]])
    {
        for (id val in dictVal)
        {
            ali::xml::tree item("item"_s);
            [NSDictionary node: item fromDictVal: val];
            node.nodes.add(item);
        }
    }else if([dictVal isKindOfClass:[NSDictionary class]])
    {
        for (NSString* key in [dictVal allKeys])
        {
            ali::xml::tree item(ali::mac::str::from_nsstring(key));
            [NSDictionary node: item fromDictVal: dictVal[key]];
            node.nodes.add(item);
        }
    }
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
+(ali::auto_ptr<ali::xml::tree>) XMLFromDictionary:(NSDictionary *) dict
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    ali::auto_ptr<ali::xml::tree> ret (new ali::xml::tree("root"_s));
    [NSDictionary node: *ret fromDictVal: dict];
    
    return ret;
}

@end
