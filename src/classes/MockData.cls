/**
 *	This is a template for custom fixtures, the existense and name of the class are irrelevant.
 *	Class name can be anything, but by default if class MockData exists then Mock will load it, unless told otherwise
 *	via Mock.MOCK_DATA variable assignment
 *
 */

public with sharing class MockData extends MockDataStandard {
	private static Map<String, Map<String, Object>> DEFAULT_VALUES_BY_TYPE = new Map<String, Map<String, Object>>();

	//add your own (new) fixture definitions here and then add their initialisation in the static section below


	//EXAMPLE
	//public static Map<String, Object> ORDER_LINE_VALUES = new Map<String, Object> {
	//	'Field_name__c' => 'value'
	//};

	//if you want to extend or overrdide standard fixture defined in MockDataStandard then do it here as well
	//EXAMPLE
	//public static Map<String, Object> ACCOUNT_VALUES = new Map<String, Object> {
	//	'Name' => 'My New Acount Name Value#{COUNTER}',//override Name definition specified in MockDataStandard
	//	'My_Field__c' => 5, //add definition for a custom field
	//	Mock.DEPENDS_ON => new Map<String, String>{'AccountId' => 'Account'} //add dependency on parent/related object
	//};
	

	static {

		//all fixture maps specified above need to be added here
		//EXAMPLE
		//DEFAULT_VALUES_BY_TYPE.put('Order_Line_Item__c', ORDER_LINE_VALUES);
		//DEFAULT_VALUES_BY_TYPE.put('Account', ACCOUNT_VALUES);

		//when you have more than 1 config for a specific Object type, use 'ObjectType#Subtype' notation
		//See MockTests class for details
		//DEFAULT_VALUES_BY_TYPE.put('Account#Customer', ACCOUNT_CUSTOMER_VALUES);
		//DEFAULT_VALUES_BY_TYPE.put('Account#Partner', ACCOUNT_PARTNER_VALUES);

	}

	public override Map<String, Object> getValueMap(final String objApiName, final Map<String, Object> fieldValues) {
		return MockData.DEFAULT_VALUES_BY_TYPE.get(objApiName);
	}

}