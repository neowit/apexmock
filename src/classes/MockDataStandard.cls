/**
 *  Copyright 2011-2012 Andrey Gavrikov.
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
 *	    default data values for mock object generator
 *
 *	    extend this class with your own Org specific data like so:
 *
 *	@isTest
 *	public with sharing class MockDataMyOrg extends MockDataStandard {
 *
 *		public static Map<String, Object> ACCOUNT_VALUES = new Map<String, Object> {
 *			'External_ID__c' => 'ext00#{COUNTER}',
 *			'Custom_Country__c' => 'Poland'
 *		};
 *		public static Map<String, Object> USER_VALUES = new Map<String, Object> {
 *			'alias' => 'Al#{COUNTER}'
 *		};
 *		public override Map<String, Map<String, Object>> getValueMap() {
 *			Map<String, Map<String, Object>> customValuesMap = new Map<String, Map<String, Object>>();
 *			customValuesMap.put('Account', ACCOUNT_VALUES);
 *			customValuesMap.put('User', USER_VALUES);
 *			return customValuesMap;
 *		}
 *	}
 *
 *	
 *	Version History :   
 *		
 */
public with sharing abstract class MockDataStandard {
	private static Map<String, Map<String, Object>> DEFAULT_VALUES_BY_TYPE = new Map<String, Map<String, Object>>();

	public static Map<String, Object> ACCOUNT_VALUES = new Map<String, Object> {
		'Name' => 'Test-' + UserInfo.getOrganizationName(),
		'Site' => 'Maidenhead'
	};
	public static Map<String, Object> LEAD_VALUES = new Map<String, Object> {
		'LastName' => 'Test Lead000#{COUNTER}',
		'Company' => 'Account-000#{COUNTER}'
	};
	public static Map<String, Object> OPPORTUNITY_VALUES = new Map<String, Object> {
		'StageName' => 'Prospecting',
		'CloseDate' => System.today()
	};

	public static Map<String, Object> USER_VALUES = new Map<String, Object> {
		'alias' => 'FAKE#{COUNTER}',
		'email' => 'FakeUser#{COUNTER}@thisisatestdomain.test',
		'emailencodingkey' => 'UTF-8',
		'lastname' => 'Test-' + UserInfo.getLastName(),
		'languagelocalekey' => 'en_US',
		'localesidkey' => 'en_US',
		'timezonesidkey' => 'America/Los_Angeles',
		'username' => 'FakeUser#{COUNTER}@'+UserInfo.getOrganizationId()+'.test'
	};

	static {
		DEFAULT_VALUES_BY_TYPE.put('Account', ACCOUNT_VALUES);
		DEFAULT_VALUES_BY_TYPE.put('Lead', LEAD_VALUES);
		DEFAULT_VALUES_BY_TYPE.put('Opportunity', OPPORTUNITY_VALUES);
		DEFAULT_VALUES_BY_TYPE.put('User', USER_VALUES);

	}

	private Map<String, Map<String, Object>> valuesByType;
	/**
	 * get custom value map of derivative class and apply it on top of default map
	 */
	private Map<String, Map<String, Object>> extendValueMap() {
		Map<String, Map<String, Object>> valueMap = DEFAULT_VALUES_BY_TYPE.clone();
		Map<String, Map<String, Object>> overrideValuesMap = getValueMap();
		for (String objName : overrideValuesMap.keySet()) {
			Map<String, Object> allValues = valueMap.get(objName);
			Map<String, Object> newValues = overrideValuesMap.get(objName);
			if (null != allValues) {
				allValues.putAll(newValues);
			} else {
				allValues = newValues.clone();
			}
			valueMap.put(objName, allValues);
		}
		//System.assert(false,'valueMap=' + valueMap);
		
		return valueMap;
	}

	/**
	 * override this method to add custom Org specific value map
	 */
	public abstract Map<String, Map<String, Object>> getValueMap();


	public Map<String, Object> getDefaultValues(final String objApiName) {
		if (null == valuesByType) {
			valuesByType = extendValueMap();
		}
		Map<String, Object> defaultValues = valuesByType.get(objApiName);
		return defaultValues;
	}
}