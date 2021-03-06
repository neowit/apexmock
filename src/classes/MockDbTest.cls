/**
 *  Copyright 2011-2017 Andrey Gavrikov.
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
 *	
 */
@isTest
public class MockDbTest  {

    static testMethod void testDbMethods () {
        final MockDb db = new MockDb();
        // INSERT
        db.insertOne(new Account(Id = '001000000000001', Name = 'Acc 1', NumberOfEmployees = 1));
        db.insertOne(new Account(Id = '001000000000002', Name = 'Acc 2', NumberOfEmployees = 2));
        final List<Sobject> recs = db.query(Schema.SObjectType.Account.getSObjectType(), new Map<String, Object>{'Name' => 'Acc 1'}).getCollection();
        System.assertEquals(1, recs.size(), 'Expected exactly 1 account with given name');
        System.assertEquals('Acc 1', recs[0].get('Name'), 'Expected exactly 1 account with given name');

        System.assertEquals('Acc 2', db.query('Account', new Map<String, Object>{'Name' => 'Acc 2'}).getCollection()[0].get('Name'), 
                                    'Expected exactly 1 account with given name');
        System.assertEquals(2, db.query(Schema.SObjectType.Account.getSObjectType()).filter('Name', new List<Object>{'Acc 2', 'Acc 1'}).size(), 
                                    'Expected exactly 2 records');

        System.debug('agX HERE');
        System.assertEquals(true, db.insertOne(new Account(Name = 'Acc 1')), 'Expected successful Insert, random Id must be assigned automatically');
        System.assertEquals(3, db.query('Account').size());
        System.assertEquals(3, db.query('Account').getCollectionOf('Name').size());
        System.assertEquals(3, db.query('Account').getSetOfIds('Id').size());
        System.assertEquals(3, db.query('Account').getMapById('Id').size());
        System.assertEquals(2, db.query('Account').getMapByString('Name').size(), 'At this point we have only 2 unique Account Names: Acc 1, Acc 2');
        
        final List<Account> accs = new List<Account>();
        accs.add(new Account(Id = '001000000000003', Name = 'Acc 3'));
        accs.add(new Account(Id = '001000000000004', Name = 'Acc 4'));
        accs.add(new Account(Id = '001000000000005', Name = 'Acc 5'));
            
        db.insertMany(accs);
        // at this point we have 6 accounts, 2 of which have name 'Acc1'
        System.assertEquals(2, db.query('Account').filter('Name', new List<Object>{'Acc 1'}).size());
        System.assertEquals(5, db.query('acCOunt').filter('Name', new List<Object>{'Acc 2', 'Acc 1', 'Acc 3', 'Acc 3', 'Acc 5'}).size());
        System.assertEquals(6, db.query('AcCOunt').filter('Name', new Set<String>{'Acc 2', 'Acc 1', 'Acc 3', 'Acc 4', 'Acc 5'}).size());
        System.assertEquals(2, db.query('AcCOunt').filter('Id', new Set<Id>{'001000000000001', '001000000000002'}).size());
        System.assertEquals(1, db.query('AcCOunt').filter('Id', '001000000000001').size());
        System.assertEquals(1, db.query('AcCOunt').filter('Id', Id.valueOf('001000000000001')).size());
        System.assertEquals(1, db.query('AcCOunt').filter('NumberOfEmployees', 2).size());
        System.assertEquals('Acc 2', db.query('AcCOunt').filter('NumberOfEmployees', 2).getCollection()[0].get('Name'));
        System.assertEquals('Acc 2', db.query('AcCOunt').filter('NumberOfEmployees', 2).head.get('Name'));

        // UPDATE
        System.assertEquals(true, db.updateOne(new Account(Id = '001000000000001', Name = 'Acc 1.1')), 'Expected successful Update');
        
        final List<Account> accsToUpdate = new List<Account>();
        accsToUpdate.add(new Account(Id = '001000000000003', Name = 'Acc 3.1'));
        accsToUpdate.add(new Account(Id = '001000000000004', Name = 'Acc 4.1'));
        accsToUpdate.add(new Account(Id = '001000000000005', Name = 'Acc 5.1'));
        System.assertEquals(new List<Boolean>{true, true, true}, db.updateMany(accsToUpdate), 'Expected successful Update');

        System.assertEquals(true, db.updateOne(new Account(Id = '001000000000001', Name = 'Acc 1.1')), 'Expected successful Update');
        System.assertEquals(2, db.query(Schema.SObjectType.Account.getSObjectType()).filter('Name', new List<Object>{'Acc 3.1', 'Acc 4.1'}).size());
        
        // UPSERT
        final List<Account> accsToUpsert = new List<Account>();
        accsToUpsert.add(new Account(Id = '001000000000004', Name = 'Acc 4.1'));
        accsToUpsert.add(new Account(Id = '001000000000005', Name = 'Acc 5.1'));
        accsToUpsert.add(new Account(Id = '001000000000006', Name = 'Acc 6'));
        System.assertEquals(new List<Boolean>{true, true, true}, db.upsertMany(accsToUpsert), 'Expected successful UPSERT');
        System.assertEquals(3, db.query(Schema.SObjectType.Account.getSObjectType()).filter('Name', new List<Object>{'Acc 4.1', 'Acc 5.1', 'Acc 6'}).size());

        db.deleteMany(new Set<Id>{'001000000000004', '001000000000005'});
        System.assertEquals(1, db.query('Account').filter('Name', new List<Object>{'Acc 4.1', 'Acc 5.1', 'Acc 6'}).size(), 'Expected only Acc 6 to pe present, because 4.1 and 5.1 should have been deleted');

        // DUMP
        System.assertNotEquals(true, db.query(Schema.SObjectType.Account.getSObjectType()).isEmpty(), 'Account must contain some records');
    }


    static testMethod void testCornerCases1 () {
        final MockDb db = new MockDb();
        System.assert(db.updateMany(new List<Account>()).isEmpty());
        System.assert(db.insertMany(new List<Account>()).isEmpty());
        System.assert(db.upsertMany(new List<Account>()).isEmpty());
        
        final List<Account> accsToUpdate = new List<Account>();
        
        accsToUpdate.add(new Account(Id = '001000000000001', Name = 'Acc 1'));
        accsToUpdate.add(new Account(Id = '001000000000002', Name = 'Acc 2'));
        System.assert(db.updateMany(accsToUpdate).isEmpty(), 'Expected failed Update because records do not exist');
        
        // contacts have not been previously touched
        db.upsertOne(new Contact(Id = '003000000000001', LastName = 'Contact 1'));
    }

    static testMethod void testCornerCases2 () {
        final MockDb db = new MockDb();
        
        // accounts collection does not exist yet
        db.upsertOne(new Account(Id = '001000000000001', Name = 'Acc 1'));
    }

    static testMethod void testCornerCases3 () {
        final MockDb db = new MockDb();
        
        // accounts collection does not exist yet
        System.assertEquals(0, db.query(Schema.SObjectType.Account.getSObjectType()).filter('Name', 'Acc 1').size());
        System.assertEquals(0, db.query(Schema.SObjectType.Account.getSObjectType(), new Map<String, Object>{'Name' => 'Acc 1'}).size());
    }

    static testMethod void testCornerCases4 () {
        final MockDb db = new MockDb();
        
        // accounts collection does not exist yet
        System.assertEquals(false, db.updateOne(new Account(Id = '001000000000001', Name = 'Acc 1')));
    }

    static testMethod void testUtilityMethods () {
        final MockDb db = new MockDb();
        
        final List<Account> accs = new List<Account>();
        accs.add(new Account(Id = '001000000000003', Name = 'Acc 3'));
        accs.add(new Account(Id = '001000000000004', Name = 'Acc 4'));
        accs.add(new Account(Id = '001000000000005', Name = 'Acc 5'));
        List<Object> values = MockDb.collectValues(accs, 'Name');
        System.assertEquals(3, values.size());
        System.assertEquals('Acc 3', values[0]);
        System.assertEquals('Acc 5', values[2]);
        final Account changedAcc = (Account)MockDb.setValues(new Account(Id = '001000000000003', Name = 'Acc 3'), new Map<String, Object>{'Name' => 'Acc 1'} );
        System.assertEquals('Acc 1', changedAcc.Name);
    }

    static testMethod void testBooleanFilter () {
        final Task tskOn = new Task(Subject = 'bool-on', IsRecurrence = true);
        final Task tskOff = new Task(Subject = 'bool-of', IsRecurrence = false);
        final List<Task> recs = new List<Task>{tskOn, tskOff};
        
        final MockDb db = new MockDb();
        db.insertMany(recs);

        System.assertEquals(2, db.query('Task').size()); 
        System.assertEquals(1, db.query('Task').filter('IsRecurrence', true).size()); 
        System.assertEquals(1, db.query('Task').filter('Subject', 'bool-on').filter('IsRecurrence', true).size()); 
        System.assertEquals(1, db.query('Task').filter('IsRecurrence', false).size()); 
    }
    
    static testMethod void testDateTimeFilters () {

        final DateTime NOW = DateTime.now();
        final String TASK_KEY_PREFIX = Schema.SObjectType.Task.getKeyPrefix();
        
        final List<Task> recs = new List<Task>();
        recs.add(new Task(Subject = 'Tsk -1', ReminderDateTime = NOW - 1));
        recs.add(new Task(Subject = 'Tsk 0', ReminderDateTime = NOW));
        recs.add(new Task(Subject = 'Tsk +1', ReminderDateTime = NOW + 1));

        final MockDb db = new MockDb();
        db.insertMany(recs);
        final Schema.SObjectType taskType = Schema.SObjectType.Task.getSObjectType();
        System.assertEquals(2, db.query(taskType).greaterOrEqual('ReminderDateTime', NOW).size()); 
        System.assertEquals(1, db.query(taskType).greaterThan('ReminderDateTime', NOW).size()); 
        System.assertEquals(1, db.query(taskType).lessThan('ReminderDateTime', NOW).size()); 
        System.assertEquals(2, db.query(taskType).lessOrEqual('ReminderDateTime', NOW).size()); 
    }

    static testMethod void testDateFilters () {
        
        final Date TODAY = Date.today();
        final List<Contact> accs = new List<Contact>();
        accs.add(new Contact(Id = '003000000000001', LastName = 'Acc -1', Birthdate = TODAY - 1));
        accs.add(new Contact(Id = '003000000000002', LastName = 'Acc 0', Birthdate = TODAY));
        accs.add(new Contact(Id = '003000000000003', LastName = 'Acc +1', Birthdate = TODAY + 1));
        
        final MockDb db = new MockDb();
        db.insertMany(accs);
        final Schema.SObjectType contactType = Schema.SObjectType.Contact.getSObjectType();
        System.assertEquals(2, db.query(contactType).greaterOrEqual('Birthdate', TODAY).size()); 
        System.assertEquals(1, db.query(contactType).greaterThan('Birthdate', TODAY).size()); 
        System.assertEquals(1, db.query(contactType).lessThan('Birthdate', TODAY).size()); 
        System.assertEquals(2, db.query(contactType).lessOrEqual('Birthdate', TODAY).size()); 
    }

    static testMethod void testDecimalFilters () {
        
        final Decimal HUNDRED = 100.00;
        final List<Account> accs = new List<Account>();
        accs.add(new Account(Id = '001000000000001', Name = 'Acc -1', AnnualRevenue = HUNDRED - 1));
        accs.add(new Account(Id = '001000000000002', Name = 'Acc 0', AnnualRevenue = HUNDRED));
        accs.add(new Account(Id = '001000000000003', Name = 'Acc +1', AnnualRevenue = HUNDRED + 1));
        
        final MockDb db = new MockDb();
        db.insertMany(accs);
        final Schema.SObjectType accountType = Schema.SObjectType.Account.getSObjectType();
        System.assertEquals(2, db.query(accountType).greaterOrEqual('AnnualRevenue', HUNDRED).size()); 
        System.assertEquals(1, db.query(accountType).greaterThan('AnnualRevenue', HUNDRED).size()); 
        System.assertEquals(1, db.query(accountType).lessThan('AnnualRevenue', HUNDRED).size()); 
        System.assertEquals(2, db.query(accountType).lessOrEqual('AnnualRevenue', HUNDRED).size()); 
    }
}