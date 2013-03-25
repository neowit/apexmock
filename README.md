apexmock
========

force.com Mock data and fixtures for Apex Unit Tests

ApexMock is a library which can assist in dummy data generation for Apex Unit Tests
     
  in order to use Mock methods Mock.MOCK_DATA has to be initialised first  
<pre>
	Mock.MOCK_DATA = new MyOrgMockDataSet1();
</pre>
If Mock.MOCK_DATA is not initialised then by default class named `MockData` will be used (if existis).

Now you can create some objects
<pre>
	//create Account and Insert into DB
	//only relevant fields need to be specified, the rest will be taken from MyOrgMockDataSet1
	Account acc1 = (Account)Mock.one('Account', 
					new Map<String, Object>{ 'MyField__c' => 'some-value', 'OtherField__c' => 123}, true); 
	//create account but do not Insert yet
	Account acc2 = (Account)Mock.one('Account', new Map<String, Object>{ 'Name' => 'Acc 2'}, false);
	acc2.MyId__c = '123456';
	Database.insert(acc2);
	...
	//generate and save 2 Opportunities using acc1 and acc2 as their Accounts
	List<Opportunity> opps = Mock.many('Opportunity', 
								new Map<String, Object>{ 'Name' => 'Opp#{COUNTER}', 
								'AccountId' => Id[] {acc1.Id, acc2.Id}}, 2, true); 
	...
	...

	//same as above, but less code, all fields except Accoun.Name are taken from fixtures 
	List&lt;Account> accs = Mock.many('Account', new Map<String, Object>{ 'Name' => 'Acc #{COUNTER}'}, 2, true)

	//using Mock.toIds() so each opportunity will receive its own account Id
	List&lt;Opportunity> opps2 = Mock.many('Opportunity', 
								new Map<String, Object>{ 'Name' => 'Opp#{COUNTER}', 
								'AccountId' => Mock.toIds(accs)}, 2, true); 
	...
	...
	
	//similar to above, but we do not care which Account each Opportunity will be assigned to, 
	//because it is not relevant in our test
	//using Mock.DEPENDS_ON
	Map<String, String> dependsOn = new Map<String, String>{'AccountId' => 'Account', 'My_Related_Object_Ref__c' => 'My_Related_Object__c'}
	List&lt;Opportunity> opps2 = Mock.many('Opportunity', 
								new Map<String, Object>{ 'Name' => 'Opp#{COUNTER}', Mock.DEPENDS_ON => dependsOn}, 2, true); 

</pre>
Another example, create 3 Contacts using only defined earlier fixtures.  
The following single line piece of code will create and save a separate Account for each contact.  
See MockDataStandard.CONTACT_VALUES for an example of how DEPENDS_ON is defined.
<pre>
	List&lt;Contact> opps2 = Mock.many('Contact', 3, true); 
</pre>
 See MockTests.cls for more comprehensive usage examples

Why ApexMock
------------
Two most popular ways to generate test data is

1. create test data individually for every test like this
<pre>
		Account acc = new Account (Name = 'Test Acc', BillingStreet = 'Some street', Custom_Field__c = 'some value'...);
		Database.insert(acc);
		Opportunity opp = new Opportunity(AccountId = acc.id, StageName = 'Prospecting', Amount = 100, Some_Field__c = 'value here', ...);
		Database.insert(opp);
</pre>
  Even if in your current test you are only interested in Opportunity.Amount and Account.Custom_field__c, you still have to initialise lots
  of other fields (e.g. Account.Name) because of validation rules.

2. In order to minimise repeated code you start writing something like this
<pre>
		public static Account createTestAccount(String name, String billingStreet, ..., Boolean saveIntoDb) {
			//account initialisation code here
		}
</pre>
  then you use it like so:
<pre>
		Account acc = MyStaticTestClass.createTestAccount('Some Name', 'Some address', ..., true);
</pre>
  With this approach you have to remember the order of parameters in each createTest\[xxx]() method or keep getting back to MyStaticTestClass
  to check what the order is.

At some point you realise that your test requires 10 Accounts and 20 Opportunities.
With approach #1 your test data generation code in each test will be massive, with approach #2 you have to generate at least twice as many
createTest\[xxx]() methods (one creating single object and 1 creating List of objects).

Later you realise that it would be nice if your static dummy data initialisation code had several very different data sets which you can use
to test logic for different business processes (or business units) in your SFDC ORG.
i.e. in one case your Contacts must have all standard fields filled in and in Spanish, in the other case you need only LastName and UK PostCode.

How do you solve that?

Will you continue increasing your createTest\[xxx]() methods base?  
Or will you define different data sets once and then just swap them with one line of code like so:

		Mock.MOCK_DATA = new MyOrgMockDataSet1();
		...
		Mock.MOCK_DATA = new MyOrgMockDataSet2();
