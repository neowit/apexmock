/**
 *  Copyright 2011-2013 Andrey Gavrikov.
 *  this file is part of ApexMock library
 *  https://github.com/neowit/apexmock
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *	limitations under the License.
 *
 *	@description:
 *		various frequently used in tests utility methods that can not be categorised
 *		into a specific area
 *	
 */

public with sharing class MockUtils {
	final static Map<String, RecordType> recordTypeByObjectAndName = new Map<String, RecordType>();//Account.Small_Business -> RecordType
	
	final static Map<String, Profile> profileMap = new Map<String, Profile>();
	
	public static Profile getProfile(final String profileName) {
		Profile prof = profileMap.get(profileName);
		if (null == prof) {
			//in theory we shall do try/catch here, but missing profile usually means either Typo or something really bad
			//so nice handling of such situation is not necessary
			prof = [select Id, Name from Profile where name =: profileName];
			profileMap.put(prof.Name, prof);
		}
		return prof;
	}

	/**
	 * @param: objectApiName - String - API name of target object, e.g. 'My_Object__c'
	 * @param: rtDeveloperName - developer name of target record type, e.g. 'Small_Business'
	 * @return - record type if found, null otherwise
	 */
	public static RecordType getRecordType(String objectApiName, String rtDeveloperName) {
		String key = (objectApiName + '.' + rtDeveloperName).toLowerCase();
		RecordType recType = recordTypeByObjectAndName.get(key);
		if (null == recType) {
			for(RecordType rt : [select Id, DeveloperName, SobjectType from RecordType where SobjectType =: objectApiName]) {
				String rtNameKey = rt.SobjectType + '.' + rt.DeveloperName;
				recordTypeByObjectAndName.put(rtNameKey.toLowerCase(), rt);
			}
			recType = recordTypeByObjectAndName.get(key);
		}
		return recType;
	}

	/**
	 * check how getProfile method works
	 */
	static testMethod void testGetProfile () {
		//every org has System Administrator profile so we can reliably test that it exists
		System.assertNotEquals(null, MockUtils.getProfile('System Administrator'), 'System Administrator profile always exists');
	}
	
	/**
	 * check how getRecordType method works
	 */
	static testMethod void testGetRecordType () {
		//check what record types this Org has
		final List<RecordType> rts = [select Id, DeveloperName, SobjectType from RecordType limit 1];
		
		Id rtExpectedId = null;
		Id rtLoadedId = null;
		if (!rts.isEmpty()) {
			RecordType rtLoaded = MockUtils.getRecordType(rts[0].SobjectType, rts[0].DeveloperName);
			RecordType rtExpected = rts[0];
			rtLoadedId = rtLoaded.Id;
			rtExpectedId = rtLoaded.Id;
		}
		//every org has System Administrator profile so we can reliably test that it exists
		System.assertEquals(rtExpectedId, rtLoadedId, 'did not find RecordType which was expected');
	}

}
