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
	
	final static Map<String, Map<String, SObject>> sobjectCache = new Map<String, Map<String, SObject>>();
	
	public static Profile getProfile(final String profileName) {
		Map<String, SObject> cachedMap = loadCache('Profile', 'name', new List<String> {profileName}, new Set<String>{'name'});
		Profile prof = (Profile)cachedMap.get(profileName);
		System.assertNotEquals(null, prof, 'Profile with name ' + profileName + ' not found');
		return prof;
	}

	public static UserRole getRole(final String roleDeveloperName) {
		UserRole role = (UserRole)loadCache('UserRole', 'DeveloperName', roleDeveloperName ).get(roleDeveloperName);
		System.assertNotEquals(null, role, 'UserRole with DeveloperName ' + roleDeveloperName + ' not found');
		return role;
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
			for(RecordType rt : [select Id, DeveloperName, SobjectType, Name from RecordType where SobjectType =: objectApiName]) {
				String rtNameKey = rt.SobjectType + '.' + rt.DeveloperName;
				recordTypeByObjectAndName.put(rtNameKey.toLowerCase(), rt);
			}
			recType = recordTypeByObjectAndName.get(key);
		}
		return recType;
	}

	public static Map<String, SObject> loadCache(final String objApiName, final String keyFieldName, final String keyVal) {
		return loadCache(objApiName, keyFieldName, new List<String>{keyVal}, new Set<String>() );
	}
	/**
	 * cache specific records for subsequent use in cals like getProfile, getRole, etc
	 */
	public static Map<String, SObject> loadCache(final String objApiName, final String keyFieldName, final List<String> keyVals, final Set<String> fieldsToCache) {
		String objApiNameLower = objApiName.toLowerCase();
		Map<String, SObject> resultMap = new Map<String, SObject>();
		Map<String, SObject> cachedMap = sobjectCache.get(objApiNameLower);
		if (null == cachedMap) {
			cachedMap = new Map<String, SObject>();
			sobjectCache.put(objApiNameLower, cachedMap);
		}
		final Set<String> keysToLoad = new Set<String>();

		for(String key : keyVals) {
			SObject objLoaded = cachedMap.get(key);
			if (null == objLoaded) {
				keysToLoad.add(key);
			} else {
				resultMap.put(key, objLoaded);
			}
		}
		
		if (!keysToLoad.isEmpty()) {
			String soqlStr = 'select Id, ' + keyFieldName;
			for(String fName : fieldsToCache) {
				if (!'id'.equalsIgnoreCase(fName) && !keyFieldName.equalsIgnoreCase(fName)) {
					soqlStr += ',' + fName;
				}
			}
			soqlStr += ' from ' + objApiName + ' where ' + keyFieldName + ' in: keysToLoad';

			for( SObject obj : Database.query(soqlStr)) {
				resultMap.put((String)obj.get(keyFieldName), obj);
			}
			cachedMap.putAll(resultMap);
		}
		return resultMap;
	}

	/**
	 * check how getProfile method works
	 */
	static testMethod void testGetProfile () {
		//assuming there is always at least 1 profile (e.g. Sys Admin and Standard User) in the org
		Profile p = [select Id, Name from Profile limit 1];
		//every org has System Administrator profile so we can reliably test that it exists
		System.assertNotEquals(null, MockUtils.getProfile(p.Name), 'Expected a Profile to be returned');
		System.assertEquals(p.Id, MockUtils.getProfile(p.Name).Id, 'Wrong profile returned');
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
		System.assertEquals(rtExpectedId, rtLoadedId, 'did not find RecordType which was expected');
	}

	/**
	 * check how getRole method works
	 */
	static testMethod void testGetRole () {
		try {
			UserRole existingRole = [select Id, DeveloperName from UserRole limit 1];
			System.assertEquals(existingRole.Id, MockUtils.getRole(existingRole.DeveloperName).Id, 
					'Expected to return Id of existing role' + existingRole.DeveloperName);
			//call same method again, but now expect to return value from cache
			System.assertEquals(existingRole.Id, MockUtils.getRole(existingRole.DeveloperName).Id, 
					'Expected to return Id of existing role' + existingRole.DeveloperName);

		} catch (Exception eIgnore) {}
	}
}