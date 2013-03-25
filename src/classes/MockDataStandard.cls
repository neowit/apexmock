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
	public static Map<String, Object> CONTACT_VALUES = new Map<String, Object> {
		'FirstName' => 'Test',
		'LastName' => 'CONTACT000#{COUNTER}',
		'Email' => 'test-person#{COUNTER}@test.com',
		//DEPENDS_ON defines what fields require other object to be created before current object can be saved
		Mock.DEPENDS_ON => new Map<String, String>{'AccountId' => 'Account'}
	};
	public static Map<String, Object> EVENT_VALUES = new Map<String, Object> {
		'Subject' => 'Test Event',
		'ActivityDateTime' => System.now(),
		'DurationInMinutes' => 60
	};
	public static Map<String, Object> LEAD_VALUES = new Map<String, Object> {
		'LastName' => 'Test Lead000#{COUNTER}',
		'Company' => 'Account-000#{COUNTER}'
	};
	public static Map<String, Object> OPPORTUNITY_VALUES = new Map<String, Object> {
		'Name' => 'Opp 000#{COUNTER}',
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
		DEFAULT_VALUES_BY_TYPE.put('Contact', CONTACT_VALUES);
		DEFAULT_VALUES_BY_TYPE.put('Event', EVENT_VALUES);
		DEFAULT_VALUES_BY_TYPE.put('Lead', LEAD_VALUES);
		DEFAULT_VALUES_BY_TYPE.put('Opportunity', OPPORTUNITY_VALUES);
		DEFAULT_VALUES_BY_TYPE.put('User', USER_VALUES);

	}

	/**
	 * override this method to add custom Org specific value map
	 * @param: objApiName - api name of salesforce object, e.g. Opportunity
	 * @fieldValues: map in values provided by user, can be empty but never null
	 * you may want to use values provided by user to do some data specific intitlaisations
	 * e.g. return different data sets depending on RecordTypeId
	 */
	public abstract Map<String, Object> getValueMap(final String objApiName, final Map<String, Object> fieldValues);


	/**
	 * main purpose of this method is to make sure that we return a copy of Fixture data rather than reference
	 * so any changes to the result returned by getDefaultValues() will not affect fixtures
	 * @param: objApiName - api name of salesforce object, e.g. Opportunity
	 * @fieldValues: map in values provided by user, can be empty but never null
	 */
	public Map<String, Object> getDefaultValues(final String objApiName, final Map<String, Object> fieldValues) {
		Map<String, Object> valueMap = DEFAULT_VALUES_BY_TYPE.get(objApiName);
		Map<String, Object> overrideValuesMap = getValueMap(objApiName, fieldValues);

		Map<String, Object> allValues = null != valueMap? valueMap.clone() : null;
		Map<String, Object> newValues = null != overrideValuesMap? overrideValuesMap.clone() : null;
		if (null == allValues && null == newValues) {
			return null;
		}
		if (null != allValues && null != newValues) {
			allValues.putAll(newValues);
		} else if (null != newValues){
			allValues = newValues.clone();
		}
		return allValues;
	}
}
