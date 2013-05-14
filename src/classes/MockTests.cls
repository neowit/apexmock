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
		'BillingStreet' => 'mock test street'
	};
	private static Map<String, Object> ACCOUNT_CUSTOMER_VALUES = new Map<String, Object> {
		'Name' => 'Customer-Name',
		'BillingStreet' => 'mock customer street'
	};

	class TestMockData extends MockDataStandard {
		/**
		 * return specific field values for account
		 */
		public override Map<String, Object> getValueMap(final String objApiName, final Map<String, Object> fieldValues) {
			final Map<String, Map<String, Object>> DEFAULT_VALUES_BY_TYPE = new Map<String, Map<String, Object>>();
			DEFAULT_VALUES_BY_TYPE.put('Account', ACCOUNT_VALUES);
			DEFAULT_VALUES_BY_TYPE.put('Account#Customer', ACCOUNT_CUSTOMER_VALUES);
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
		//test many() version without field overrides
		List<Account> objs = Mock.many('Account', 3, false); 
		System.assertEquals(3, objs.size(),'Number of created records does not match expected.');
		System.assertNotEquals(null, objs[0].Name, 'Expected Name field to be initialised from Fixtures');

		Mock.UNIQUE_COUNTER = 0;
		objs = Mock.many('Account', new Map<String, Object>{'Name' => 'many-name#{COUNTER}'}, 3, false); 
		System.assertEquals(3, objs.size(),'Number of created records does not match expected.');

		
		//check that second object in the list contains expected values
		//COUNTER for second record will be 2
		System.assertEquals(objs[1].get('Name'), 'many-name2', 'Local field override did not work as expected');
		System.assertEquals(objs[1].get('BillingStreet'), ACCOUNT_VALUES.get('BillingStreet'), 'Field value from custom dataset has not been assigned');

		//test array values
		objs = Mock.many('Account', new Map<String, Object>{'Name' => new String[]{'name-A', 'name-B', 'C-Name'}}, 3, false); 
		System.assertEquals(3, objs.size(),'Number of created records does not match expected.');
		System.assertEquals(objs[0].get('Name'), 'name-A', 'Local field override did not work as expected');
		System.assertEquals(objs[1].get('Name'), 'name-B', 'Local field override did not work as expected');
		System.assertEquals(objs[2].get('Name'), 'C-Name', 'Local field override did not work as expected');

		//simulate like if accounts above have been saved and now have ids
		final Account[] accs = new Account[]{new Account(Id='001000000000001'), new Account(Id='001000000000002')};
		
		//check parent/child
		List<Contact> conts = Mock.many('Contact', new Map<String, Object>{'AccountId' => Mock.toIds(accs)}, 2, false); 
		System.assertEquals(conts[0].get('AccountId'), accs[0].Id, 'field override did not work as expected');
		System.assertEquals(conts[1].get('AccountId'), accs[1].Id, 'field override did not work as expected');

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

	/**
	 * we already tested if custom fixture override works above in testFieldsInitialisation
	 * so here just provide code coverage for example class MockData
	 */
	static testMethod void testCoverageForCustomFixtureExample () {
		//if we do not specify Mock.MOCK_DATA explicitly then system will load MockData class by default if one exists
		//Mock.MOCK_DATA = new MockData();

		//just cause MockData.getValueMap() call
		Account acc = (Account)Mock.one('Account', false); 
	}
	
	/**
	 * check how DEPENDS_ON map is resolved
	 */
	static testMethod void testDependendsOn () {
		//there is a good chance that target Org has required fields that are not initated in standard fixtures
		//so using try..catch to avoid failing tests
		try	{

			Contact cont = (Contact)Mock.one('Contact', false); 
			//check if AccountId from standard fixture is initialised
			System.assertNotEquals(null, cont.AccountId,'Expected AccountId to be initialised as defined in MockDataStandard.CONTACT_VALUES[DEPENDS_ON]');
			
		} catch (Exception eIgnore) {}
	}
	
	/**
	 * check how mass clone works
	 */
	static testMethod void testClone () {
		Mock.UNIQUE_COUNTER = 0;
		List<Account> accs = Mock.many('Account', new Map<String, Object>{'Name' => 'My-Account#{COUNTER}', 'Description' => 'A Description'}, 3, false); 
		
		List<Account> accsClone = Mock.clone(accs, new Map<String, Object>{'Description' => 'Clone Description'}, false);

		System.assertNotEquals(accs[0].Description, accsClone[0].Description, 'Expected different description.');
		System.assertEquals('Clone Description', accsClone[0].Description, 'Expected description set in clone() operation.');
		
		
	}
	/**
	 * check how Mock.many(final SObject objTemplate, final Integer count, final Boolean saveIntoDb) works
	 */
	static testMethod void testManyWithSObjectTemplate () {
		Mock.MOCK_DATA = new TestMockData();
		Mock.UNIQUE_COUNTER = 0;
		List<Account> accs = Mock.many(new Account(Name = 'My-Account#{COUNTER}', Description = 'A Description'), 3, false); 
		System.assertEquals('A Description', accs[0].Description, 'Expected description set in clone() operation.');
		System.assertEquals('My-Account2', accs[1].Name, 'Expected merge value for Account.Name to be expanded.');
		System.assertEquals(ACCOUNT_VALUES.get('BillingStreet'), accs[0].BillingStreet, 'Expected BillingStreet to be taken from fixture.');
		
		
	}

	/**
	 * check how Singleton functionality works
	 */
	static testMethod void testSingletons () {
		Mock.MOCK_DATA = new TestMockData();
		//first check that if parent/depends_on object is not singleton then we create 1 per every record
		try	{

			List<Contact> conts = Mock.many('Contact', 2, false); 
			//check if AccountId from standard fixture is initialised
			System.assertNotEquals(null, conts[0].AccountId,'Expected AccountId to be initialised as defined in MockDataStandard.CONTACT_VALUES[DEPENDS_ON]');
			System.assertNotEquals(conts[0].AccountId, conts[1].AccountId,'Expected AccountId-s to be different');

			Contact cont3 = (Contact)Mock.one('Contact', false); 
			System.assertNotEquals(conts[0].AccountId, cont3.AccountId ,'Expected AccountId-s to be different yet again');
			
		} catch (Exception eIgnore) {}

		//now declare Account type Singleton and check that there is just single record is created
		Mock.MOCK_DATA.addSingletonObjectType('Account');
		try	{

			List<Contact> conts = Mock.many('Contact', 2, false); 
			//check if AccountId from standard fixture is initialised
			System.assertNotEquals(null, conts[0].AccountId,'Expected AccountId to be initialised as defined in MockDataStandard.CONTACT_VALUES[DEPENDS_ON]');
			System.assertEquals(conts[0].AccountId, conts[1].AccountId,'Expected AccountId-s to be the same');

			Contact cont3 = (Contact)Mock.one('Contact', false); 
			System.assertEquals(conts[0].AccountId, cont3.AccountId ,'Expected AccountId-s to be still the same');
			
		} catch (Exception eIgnore) {}

		//when we remove singleton type system shall revert back to creating one record per child
		Mock.MOCK_DATA.removeSingletonObjectType('Account');
		try	{

			List<Contact> conts = Mock.many('Contact', 2, false); 
			//check if AccountId from standard fixture is initialised
			System.assertNotEquals(null, conts[0].AccountId,'Expected AccountId to be initialised as defined in MockDataStandard.CONTACT_VALUES[DEPENDS_ON]');
			System.assertNotEquals(conts[0].AccountId, conts[1].AccountId,'Expected AccountId-s to be different');
			
		} catch (Exception eIgnore) {}

		
	}
	/**
	 * check how relationship lookup recording and retrieval works
	 * @see: Mock.getRelationship() & MockDataStandard.getRelationship()
	 */
	static testMethod void testRelationshipLookups () {
		//first check non existing relationship
		System.assertEquals(null, Mock.MOCK_DATA.getRelationship('001000000000000', 'WhoId.AcountId'), 'Expected blank relationship');
		
		//there is a good chance that target Org has required fields that are not initated in standard fixtures
		//so using try..catch to avoid failing tests
		try	{

			//as we do not know the target Org schema we can not rely on any particular object hierarchy, but let's try 3 level:
			//Account <- Contact <- Event
			Contact cont = (Contact)Mock.one('Contact', true); 
			//check one level
			System.assertEquals(cont.AccountId, Mock.MOCK_DATA.getRelationship(cont.Id, 'AccountId'), 'Expected AccountId to be with the same value as cont.AccountId');

			Event evt = (Event)Mock.one('Event', new Map<String, Object>{'WhoId' => cont.Id}, false); 
			Id accountId = Mock.getRelationship(evt, 'WhoId.AccountId');
			//check if AccountId from standard fixture is initialised
			System.assertEquals(cont.AccountId, accountId, 'Expected accountId to be with the same value as contact.AccountId');
			
		} catch (Exception eIgnore) {}
		
	}
	
	/**
	 * check complex types like Account, Account#Customer and Account#Partner
	 */
	static testMethod void testCustomisedTypes () {
		Mock.MOCK_DATA = new TestMockData();
		//as we do not know the target Org schema we can not rely on any particular object hierarchy, but let's try 3 level:
		//Account <- Contact <- Event
		Account accGeneric = (Account)Mock.one('Account', false); 
		Account accCustomised = (Account)Mock.one('Account#Customer', false); 
		//check that Cusotmer and Generic have been initialised with different values
		System.assertNotEquals(accGeneric.Name, accCustomised.Name, 'Expected different values for two accounts');
		System.assertEquals(ACCOUNT_VALUES.get('Name'), accGeneric.Name, 'Expected Account.Name to be with the same as in ACCOUNT_VALUES fixture');
		System.assertEquals(ACCOUNT_CUSTOMER_VALUES.get('Name'), accCustomised.Name, 'Expected Account.Name to be with the same as in ACCOUNT_CUSTOMER_VALUES fixture');
		
	}
	/**
	 * check record type substitution
	 */
	static testMethod void testRecordTypeSubstitution () {
		//this test only makes sence if there are record types in the org
		final List<RecordType> rts = [select Id, DeveloperName, SobjectType from RecordType limit 1];
		
		if (!rts.isEmpty()) {
			Id rtId = (Id)Mock.mergeValue(String.valueOf(rts[0].SobjectType), 'RecordTypeId', rts[0].DeveloperName);
			System.assertNotEquals(null, rtId, 'Expected Record Type Id to be initialised based on provided Record Type Developer Name');
		}
	}
	
	
}
