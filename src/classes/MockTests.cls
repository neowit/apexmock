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
 *	    unit tests and usage examples for Mock and MockDataStandard
 *	
 *	Version History :   
 *		
 */
@isTest
public with sharing class MockTests {
	//////////////////////// unit tests /////////////////////////////////////
	private static Map<String, Object> ACCOUNT_VALUES = new Map<String, Object> {
		'Name' => 'Alternate-Name',
		'BillingStreet' => 'other'
	};
	class TestMockData extends MockDataStandard {
		/**
		 * return specific field values for account
		 */
		public override Map<String, Object> getValueMap(final String objApiName, final Map<String, Object> fieldValues) {
			final Map<String, Map<String, Object>> DEFAULT_VALUES_BY_TYPE = new Map<String, Map<String, Object>>();
			DEFAULT_VALUES_BY_TYPE.put('Account', ACCOUNT_VALUES);
			return DEFAULT_VALUES_BY_TYPE.get(objApiName);
		}
	}
	/**
	 * check that Mock initialises correct fieds based on object type
	 */
	static testMethod void testFieldsInitialisation () {
		//check if custom override works
		Mock.MOCK_DATA = new TestMockData();
		Account obj = (Account)Mock.one('Account'); 
		//we did not override Site, so it should be the same as default
		System.assertEquals(obj.Site, MockDataStandard.ACCOUNT_VALUES.get('Site'), 'Should have preserved standard Site value');
		//
		System.assertNotEquals(obj.Name, MockDataStandard.ACCOUNT_VALUES.get('Name'), 'Failed to override field Name');
		System.assertEquals(obj.get('BillingStreet'), ACCOUNT_VALUES.get('BillingStreet'), 'BillingStreet field from custom dataset not found');
		
		//test another signature of Mock.one();
		obj = (Account)Mock.one('Account', false); 
		//we did not override Site, so it should be the same as default
		System.assertEquals(obj.Site, MockDataStandard.ACCOUNT_VALUES.get('Site'), 'Should have preserved standard Site value');
		
	}
	static testMethod void testLocalFieldOverride () {
		//check if custom override works
		Mock.MOCK_DATA = new TestMockData();
		Account obj = (Account)Mock.one('Account', false); 
		System.assertEquals(obj.get('BillingStreet'), ACCOUNT_VALUES.get('BillingStreet'), 'BillingStreet field from custom dataset not found');
		//
		Account obj2 = (Account)Mock.one('Account', new Map<String, Object>{'BillingStreet' => 'Another Value'}); 
		System.assertEquals(obj2.get('BillingStreet'), 'Another Value', 'BillingStreet field value should have been from local override');

	}
	static testMethod void testMockMany () {
		//check if custom override works
		Mock.MOCK_DATA = new TestMockData();
		Mock.UNIQUE_COUNTER = 0;
		List<Account> objs = (List<Account>)Mock.many('Account', new Map<String, Object>{'Name' => 'many-name#{COUNTER}'}, 3, false); 
		System.assertEquals(3, objs.size(),'Number of created records does not match expected.');
		
		//check that second object in the list contains expected values
		//COUNTER for second record will be 2
		System.assertEquals(objs[1].get('Name'), 'many-name2', 'Local field override did not work as expected');
		System.assertEquals(objs[1].get('BillingStreet'), ACCOUNT_VALUES.get('BillingStreet'), 'Field value from custom dataset has not been assigned');

		//test array values
		objs = (List<Account>)Mock.many('Account', new Map<String, Object>{'Name' => new String[]{'name-A', 'name-B', 'C-Name'}}, 3, false); 
		System.assertEquals(3, objs.size(),'Number of created records does not match expected.');
		System.assertEquals(objs[0].get('Name'), 'name-A', 'Local field override did not work as expected');
		System.assertEquals(objs[1].get('Name'), 'name-B', 'Local field override did not work as expected');
		System.assertEquals(objs[2].get('Name'), 'C-Name', 'Local field override did not work as expected');

	}
	static testMethod void testMergeFields () {
		//check if custom override works
		Mock.MOCK_DATA = new TestMockData();
		Mock.UNIQUE_COUNTER = 0;
		System.assertEquals('1value1', Mock.mergeValue('#{COUNTER}value#{COUNTER}'),'Expected same Counter value twice');
		//check that counter actually changes every time
		Object originalCounter = Mock.mergeValue('#{COUNTER}value');
		System.assertNotEquals(originalCounter, Mock.mergeValue('#{COUNTER}value'),'Expected different Counter value');
		
		//check unique email
		System.assertNotEquals(Mock.mergeValue('#{EMAIL}'), Mock.mergeValue('#{EMAIL}'),'Expected different email addresses');
		
	}

	static testMethod void testTopUp () {
		Mock.MOCK_DATA = new TestMockData();
		Account acc = new Account();
		acc.Name = 'Should Stay';
		Mock.populateNulls(acc);
		System.assertEquals('Should Stay', acc.Name, 'Previously defined field value must have been preserved');
		System.assertEquals(ACCOUNT_VALUES.get('BillingStreet'), acc.BillingStreet, 'Undefined value must have been loaded from Fixture');

	}
}
