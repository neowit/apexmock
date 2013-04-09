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
 *	 List<Opportunity> opps = Mock.many('Opportunity', 
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
	public static String DEPENDS_ON = 'depends_on';

	static {
		//if there is MockData then instantiate it
		Type t = Type.forName('MockData');
		if (null != t) {
			MOCK_DATA = (MockDataStandard)t.newInstance();

		}
	}
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
	 *
	 * @param: objApiName - API Name of SObject, ex: My_Object__c or Account
	 * @param: fieldValues - user defined values which shall overwrite default values from fixture data
	 * @param: saveIntoDb - if true then attempt to Save result via Database.insert(obj)
	 */
	public static SObject one(final String objApiName, final Map<String, Object> fieldValues, final Boolean saveIntoDb) {

		//instantiate SObject
		SObject obj = createObject(objApiName);
		populateFieldValues(obj, fieldValues);

		if (saveIntoDb) {
			Database.insert(obj);
		}
		return obj;
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
	 * same as Mock.many with 4 params above, but this one to be used when we do not want to specify anything extra
	 * and values of all fields are to be initiated from Fixtures
	 */
	public static List<SObject> many(final String objApiName, final Integer count, final Boolean saveIntoDb) {
		return many(objApiName, new Map<String, Object>{}, count, saveIntoDb );
	}
	/**
	 * same as Mock.many with 4 parameters but using provided SObject as a tempalte instead of field values map
	 * Merge values will be expanded and all other fields initiated from Fixtures
	 * e.g.
	 * final List<Account> accs = Mock.many(new Account(Name = 'Acc#{COUNT}', OwnerId = UserInfo.getUserId()), 3, true);
	 * will create 3 Accounts with Names = 'Acc1', 'Acc2', 'Acc3' and current user as Owner
	 * All other fields will be initiated as defined in Fixtures (MockDataStandard and other)
	 *
	 * CAVEAT: unlike other methods that accept  "Map<String, Object> fieldValues" - in case of template SObject
	 * we can not identify whether user deliberately provided NULL value for a certain field or this field is not initialised
	 * So if you need to specify NULL for a field then use Mock.Many(objApiName, fieldValues, count, saveIntoDb)
	 */
	public static List<SObject> many(final SObject objTemplate, final Integer count, final Boolean saveIntoDb) {
		//figure out what fields user has initialised
		String objApiName = getObjectApiName(objTemplate);
		Map<String, Schema.SObjectField> fieldMap = getFieldMap(objApiName);

		final Map<String, Object> fieldValues = new Map<String, Object>();
		for (String fName : fieldMap.keySet()) {
			fName = fName.toLowerCase();
			if (null != objTemplate.get(fName)) {
				fieldValues.put(fName, objTemplate.get(fName));
			}
		}
		
		final List<SObject> objs = new List<SObject>();
		for (Integer i=0; i< count; i++) {
			SObject obj = createObject(objApiName);
			populateFieldValues(obj, fieldValues);
			objs.add(obj);
		}
		if (saveIntoDb) {
			Database.insert(objs);
		}
		return objs;
	}

	/**
	 * using given objs as a template create their clones and overwrite values of provided fieldValues
	 * @param: objs - list of Sobjects to use as data template
	 * @param: fieldValues - user defined values which shall overwrite data from template objects
	 * @param: saveIntoDb - if true then attempt to Save result via Database.insert(obj)
	 */
	public static List<SObject> clone(List<SObject> objs, final Map<String, Object> fieldValues, final Boolean saveIntoDb) {
		final List<SObject> objClones = new List<SObject>();
		for (SObject obj : objs) {
		    SObject objClone = obj.clone(false, true);
			populateFieldValues(objClone, fieldValues);
			objClones.add(objClone);
		}
		if (saveIntoDb) {
			Database.insert(objClones);
		}
		return objClones;
	}

	/**
	 * when SObject has been previously initialised we may want to top-up missing field values 
	 * from fixtures data
	 */
	public static SObject populateNulls(final SObject obj) {
		String objApiName = getObjectApiName(obj);
		final Map<String, Object> defaultValues = MOCK_DATA.getDefaultValues(objApiName,  new Map<String, Object>());
		for (String fName : defaultValues.keySet()) {
			if (null == obj.get(fName)) {
				obj.put(fName, mergeValue(defaultValues.get(fName)));
			}
		}
		return obj;
	}

	public static Integer UNIQUE_COUNTER = 0;
	/**
	 * if value is of type string and contains #{function} then apply that functions
	 */
	public static Object mergeValue(final Object val) {
		Object resVal = val;
		if (null != val && val instanceof String) {
			String strVal = (String)val;
			if (containsFunction(strVal, 'COUNTER_I')) {//integer counter
				UNIQUE_COUNTER++;
				resVal = UNIQUE_COUNTER;
			} else {
				if (containsFunction(strVal, 'EMAIL')) {
					strVal = (String)setFunctionValue(strVal, 'EMAIL', 'test-email#{COUNTER}@a' + UserInfo.getUserId() + 'b.tst');
				}
				if (containsFunction(strVal, 'COUNTER')) {
					UNIQUE_COUNTER++;
					strVal = (String)setFunctionValue(strVal, 'COUNTER', '' + UNIQUE_COUNTER);
				}
				resVal = strVal;
			}
		}
		
		return resVal;
	}

	/**
	 * helper method, useful to get Ids of parent records created with Mock.many to use in another Mock.many for children
	 * ex: 
	 * List<Account> accs = (List<Account>)Mock.many('Account', new Map<String, Object>{'Name' => 'Test Account#{COUNTER}'}, 2, true);
	 * Mock.many('Opportunity', new Map<String, Object>{'Name'=> 'Test Opp#{COUNTER}', 'AccountId' => Mock.toIds(accs)...)
	 */
	public static List<Id> toIds(List<SObject> recs) {
		return toIds(recs, 'id');
	}

	/**
	 * same as toIds(recs) but we can also specify what field to use, as opposed to it just be 'id' 
	 */
	public static List<Id> toIds(List<SObject> recs, final String fName) {
		List<Id> ids = new List<Id>();
		for (SObject rec : recs) {
			Id idVal = (Id)rec.get(fName);
			System.assertNotEquals(null, idVal, 'All records passed to toIds() must have not NULL '+fName+'(s). This record does not: ' + rec);
			ids.add(idVal);
		}
		return ids;
	}

	/**
	 * Map is case-sensitive but we do not know the case in which user will provide values, so have to 
	 * spend extra effort to bring everything to lower case
	 */
	public static Map<String, Object> toLowerCaseMap(final Map<String, Object> fieldValues) {
		final Map<String, Object> lowerCaseMap = new Map<String, Object>();
		if (null != fieldValues) {
			for (String fName : fieldValues.keySet()) {
				lowerCaseMap.put(fName.toLowerCase(), fieldValues.get(fName));
			}
		}
		return lowerCaseMap;

	}

	//////////////////////////////////////////////////////////////////////////////////////////////////
	private static SObject populateFieldValues(SObject obj, final Map<String, Object> fieldValues) {
		System.assert(null != fieldValues, 'param fieldValues must not be null.');
		//check if given objApiName is supported
		String objApiName = String.valueOf(obj.getSObjectType());
		System.assert(null != MOCK_DATA, 'Mock.MOCK_DATA is not initialised. Assign your data fixture to Mock.MOCK_DATA first.');
		final Map<String, Object> fieldValuesInternal = toLowerCaseMap(fieldValues);
		Map<String, Object> defaultValues = toLowerCaseMap(MOCK_DATA.getDefaultValues(objApiName, fieldValuesInternal));
		System.assert(null != defaultValues,'Mock Data for type ' + objApiName + ' is not defined. Define data first.');
		

		//assign provided fields
		for (String fName : fieldValuesInternal.keySet()) {
			//single value
			if (DEPENDS_ON != fName) {
				obj.put(fName, mergeValue(fieldValuesInternal.get(fName)));
				defaultValues.remove(fName);//remove provided field from default values map
			}
		}

		//assign default fields
		for (String fName : defaultValues.keySet()) {
			//single value
			if (DEPENDS_ON != fName) {
				obj.put(fName, mergeValue(defaultValues.get(fName)));
			}
		}

		//initialise dependencies based on user provided values
		final Map<String, Object> dependsOn = (Map<String, Object>)fieldValuesInternal.get(DEPENDS_ON);
		Map<String, SObject> recordByFieldName = initDependencies(obj, dependsOn, new Map<String, SObject>());
		assignDependencies(obj, dependsOn, recordByFieldName);

		//now check if defaultValues contains DEPENDS_ON which has not yet been created
		dependsOn = (Map<String, Object>)defaultValues.get(DEPENDS_ON);
		recordByFieldName = initDependencies(obj, dependsOn, recordByFieldName);
		assignDependencies(obj, dependsOn, recordByFieldName);
		return obj;
	}

	private static sObject createObject(String typeName) {
		Schema.SObjectType targetType = gd.get(typeName);
		System.assertNotEquals(null, targetType, 'Failed to get Describe for type: ' + typeName);
		
		// Instantiate an sObject with the type passed in as an argument at run time.
		return targetType.newSObject();
	}
	private static Map<String, Schema.SObjectField> getFieldMap(String typeName) {
		Schema.SObjectType targetType = gd.get(typeName);
		System.assertNotEquals(null, targetType, 'Failed to get Describe for type: ' + typeName);
		return targetType.getDescribe().fields.getMap();
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
	
	/**
	 *	DEPENDS_ON defines what fields require other object to be created before current object can be saved
	 *	...
	 *	Mock.DEPENDS_ON => new Map<String, String>{'AccountId' => 'Account', 'My_Obj_Ref__c' => 'My_Obj__c'...}
	 *	...
	 *
	 * @param: obj - SObject record which we are currently mocking
	 * @param: dependsOn - fieldName => ObjectTypeName map
	 * @param: recordByFieldName - fieldName => SObject - earlier created records
	 */
	private static Map<String, SObject> initDependencies(final SObject obj, final Map<String, Object> dependsOn, final Map<String, SObject> recordByFieldName) {

		if (null != dependsOn) {
		
			for (String fName : dependsOn.keySet()) {
				if (null == obj.get(fName) && !recordByFieldName.containsKey(fName)) {//no need to create a parent record for the same field twice
					String objType = (String)dependsOn.get(fName);
					//init object from standard fixtures and Save
					SObject relatedObj = (SObject)Mock.one(objType, true);
					recordByFieldName.put(fName, relatedObj);
				}
			}
		}

		return recordByFieldName;
		

	}

	/**
	 * for every field mentioned as a Key in dependsOn assign Id of record from recordByFieldName
	 */
	private static void assignDependencies(final SObject obj, final Map<String, Object> dependsOn, Map<String, SObject> recordByFieldName) {
		if (null != dependsOn) {
			for (String fName : dependsOn.keySet()) {
				if (null == obj.get(fName)) {
					SObject relatedObj = recordByFieldName.get(fName);
					if (null != relatedObj) {
						obj.put(fName, (Id)relatedObj.get('id'));
					}
				}
			}
		}
	}

	private static String getObjectApiName(SObject obj) {
		//String objApiName = obj.getSObjectType().getDescribe().getName();
		return String.valueOf(obj.getSObjectType());//TODO check how this works when Namespace is involved
	}
}
