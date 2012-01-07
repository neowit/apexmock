apexmock
========

force.com Mock data and fixtures for Apex Unit Tests

ApexMock is a library which can assist in dummy data generation for Apex Unit Tests
     
  in order to use Mock methods Mock.MOCK_DATA has to be initialised first
  for example:

	Mock.MOCK_DATA = new MyOrgMockData();
	//now you can create some objects
	//create Account and Insert into DB
	Account acc1 = (Account)Mock.one('Account', 
					new Map<String, Object>{ 'MyField__c' => 'some-value', 'OtherField__c' => 123}, true); 
	//create account but do not Insert yet
	Account acc2 = (Account)Mock.one('Account', new Map<String, Object>{ 'Name' => 'Acc 2'}, false); 
	acc2.MyId__c = '123456';
	Database.insert(acc2);
	...
	//generate and save 2 Opportunities using acc1 and acc2 as their Accounts
	List<Opportunity> opps = (List<Opportunity>)Mock.many('Opportunity', 
							new Map<String, Object>{ 'Name' => 'Opp#{COUNTER}', 
										'AccountId' => Id[] {acc1.Id, acc2.Id}}, 2, true); 

 See MockTests.cls for more comprehensive usage examples

