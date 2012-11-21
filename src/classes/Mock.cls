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
 *		Mock object generator
 *		this is a very basic Apex Unit Test Data Factory inspired by FactoryGirl 
 *		and other similar Mock Test frameworks
 *	    
 *	 in order to use Mock methods Mock.MOCK_DATA has to be initialised first
 *	 for example:
 *	 Mock.MOCK_DATA = new MyOrgMockData();
 *	 //now you can create some objects
 *   //create Account and Insert into DB
 *	 Account acc1 = (Account)Mock.one('Account', new Map<String, Object>{ 'MyField__c' => 'some-value', 'OtherField__c' => 123}, true); 
 *	 //create account but do not Insert yet
 *	 Account acc2 = (Account)Mock.one('Account', new Map<String, Object>{ 'Name' => 'Acc 2'}, false); 
 *	 acc2.MyId__c = '123456';
 *	 Database.insert(acc2);
 *	 ...
 *	 //generate and save 2 Opportunities using acc1 and acc2 as their Accounts
 *	 List<Opportunity> opps = (List<Opportunity>)Mock.many('Opportunity', 
 *									new Map<String, Object>{ 'Name' => 'Opp#{COUNTER}', 'AccountId' => Id[] {acc1.Id, acc2.Id}}, 2, true); 
 *
 *  See MockTests.cls for more comprehensive usage examples
 *
 *	
 *	Version History :   
 *		
 */
public with sharing class Mock {
	public static MockDataStandard MOCK_DATA = null;//instantiate here your default custom MockData class or null
													//see MockTests.cls for examples

	private static Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
	

	/**
	 * use this if Database.insert is not required
	 */
	public static SObject one(final String objApiName, final Map<String, Object> fieldValues) {
		return one(objApiName, fieldValues, false);
	}
	/**
	 * use this if Database.insert is not required and all default field values are ok.
	 */
	public static SObject one(final String objApiName) {
		return one(objApiName, new Map<String, Object>(), false);
	}
	public static SObject one(final String objApiName, final Boolean saveIntoDb) {
		return one(objApiName, new Map<String, Object>(), saveIntoDb);
	}

	/**
	 * create multiple instances of object of specified type
	 * it is recommended that fieldValues contains a field with #{COUNTER} merge value
	 * this way created objects will not be identical
	 */
	public static List<SObject> many(final String objApiName, final Map<String, Object> fieldValues, final Integer count, final Boolean saveIntoDb) {
		final List<SObject> objs = new List<SObject>();
		for (Integer i=0; i < count; i++) {
			//single object values
			Map<String, Object> oneRecordValues = new Map<String, Object>();
			for (String fName : fieldValues.keySet()) {
				if (fieldValues.get(fName) instanceof List<Object>) {
					//array of values
					List<Object> values = (List<Object>)fieldValues.get(fName);
					System.assert(values.size() > i,'Index ' + i + ' is too large for provided list of values of field ' + fName);
					oneRecordValues.put(fName, values[i]);
				} else {
					//single value
					oneRecordValues.put(fName, fieldValues.get(fName));
				}
			}
			objs.add(one(objApiName, oneRecordValues, false));
		}
		if (saveIntoDb) {
			Database.insert(objs);
		}
		return objs;
		
	}
	/**
	 *
	 * @param: objApiName - API Name of SObject, ex: My_Object__c or Account
	 * @param: fieldValues - user defined values which shall overwrite default values from fixture data
	 * @param: saveIntoDb - if true then attempt to Save result via Database.insert(obj)
	 */
	public static SObject one(final String objApiName, final Map<String, Object> fieldValues, final Boolean saveIntoDb) {
		System.assert(null != fieldValues, 'param fieldValues must not be null.');
		//check if given objApiName is supported
		System.assert(null != MOCK_DATA, 'Mock.MOCK_DATA is not initialised. Assign your data fixture to Mock.MOCK_DATA first.');
		Map<String, Object> defaultValues = MOCK_DATA.getDefaultValues(objApiName, fieldValues);
		System.assert(null != defaultValues,'Mock Data for type ' + objApiName + ' is not defined. Define data first.');
		
		//instantiate SObject
		SObject obj = createObject(objApiName);

		//assign provided fields
		for (String fName : fieldValues.keySet()) {
			//single value
			obj.put(fName, mergeValue(fieldValues.get(fName)));
			defaultValues.remove(fName);//remove provided field from default values map
		}

		//assign default fields
		for (String fName : defaultValues.keySet()) {
		    obj.put(fName, mergeValue(defaultValues.get(fName)));
		}

		if (saveIntoDb) {
			Database.insert(obj);
		}
		return obj;
	}

	/**
	 * when SObject has been previously initialised we may want to top-up missing field values 
	 * from fixtures data
	 */
	public static SObject populateNulls(final SObject obj) {
		String objApiName = obj.getSObjectType().getDescribe().getName();//TODO check if it counts against Describe limits
		final Map<String, Object> defaultValues = MOCK_DATA.getDefaultValues(objApiName,  new Map<String, Object>());
		for (String fName : defaultValues.keySet()) {
			if (null == obj.get(fName)) {
				obj.put(fName, mergeValue(defaultValues.get(fName)));
			}
		}
		return obj;
	}
	private static sObject createObject(String typeName) {
		Schema.SObjectType targetType = gd.get(typeName);
		System.assertNotEquals(null, targetType, 'Failed to get Describe for type: ' + typeName);
		
		// Instantiate an sObject with the type passed in as an argument at run time.
		return targetType.newSObject();
	}

	public static Integer UNIQUE_COUNTER = 0;
	/**
	 * if value is of type string and contains #{function} then apply that functions
	 */
	public static Object mergeValue(final Object val) {
		Object resVal = val;
		if (null != val && val instanceof String) {
			String strVal = (String)val;
			if (containsFunction(strVal, 'EMAIL')) {
				strVal = (String)setFunctionValue(strVal, 'EMAIL', 'test-email#{COUNTER}@a' + UserInfo.getUserId() + 'b.tst');
			}
			if (containsFunction(strVal, 'COUNTER')) {
				UNIQUE_COUNTER++;
				strVal = (String)setFunctionValue(strVal, 'COUNTER', '' + UNIQUE_COUNTER);
			}
			resVal = strVal;
		}
		return resVal;//no substitution
	}

	/**
	 * @param: val - string to check for function name
	 * this method assumes that val is NOT null
	 */
	private static Boolean containsFunction(final String val, final String functionName) {
		return val.contains('#{'+functionName+'}');
	}

	/**
	 * replace predefined merge function with its value
	 */
	private static Object setFunctionValue(final String val, final String functionName, final String value) {
		return val.replaceAll('#\\{'+functionName+'\\}', value);
	}
	
}
