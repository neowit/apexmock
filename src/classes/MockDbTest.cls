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
        db.insertOne(new Account(Id = '001000000000001', Name = 'Acc 1'));
        db.insertOne(new Account(Id = '001000000000002', Name = 'Acc 2'));
        final List<Sobject> recs = db.query(Schema.SObjectType.Account.getSObjectType(), new Map<String, Object>{'Name' => 'Acc 1'});
        System.assertEquals(1, recs.size(), 'Expected exactly 1 account with given name');
        System.assertEquals('Acc 1', recs[0].get('Name'), 'Expected exactly 1 account with given name');

        System.assertEquals('Acc 2', db.query(Schema.SObjectType.Account.getSObjectType(), new Map<String, Object>{'Name' => 'Acc 2'})[0].get('Name'), 
                                    'Expected exactly 1 account with given name');
        System.assertEquals(2, db.query(Schema.SObjectType.Account.getSObjectType(), 'Name', new List<Object>{'Acc 2', 'Acc 1'}).size(), 
                                    'Expected exactly 2 records');

        System.assertEquals(false, db.insertOne(new Account(Id = '001000000000001', Name = 'Acc 1')), 'Expected failed Insert, record with this Id already exists');
        
        final List<Account> accs = new List<Account>();
        accs.add(new Account(Id = '001000000000003', Name = 'Acc 3'));
        accs.add(new Account(Id = '001000000000004', Name = 'Acc 4'));
        accs.add(new Account(Id = '001000000000005', Name = 'Acc 5'));
            
        db.insertMany(accs);
        System.assertEquals(5, db.query(Schema.SObjectType.Account.getSObjectType(), 'Name', new List<Object>{'Acc 2', 'Acc 1', 'Acc 3', 'Acc 3', 'Acc 5'}).size());

        // UPDATE
        System.assertEquals(true, db.updateOne(new Account(Id = '001000000000001', Name = 'Acc 1.1')), 'Expected successful Update');
        
        final List<Account> accsToUpdate = new List<Account>();
        accsToUpdate.add(new Account(Id = '001000000000003', Name = 'Acc 3.1'));
        accsToUpdate.add(new Account(Id = '001000000000004', Name = 'Acc 4.1'));
        accsToUpdate.add(new Account(Id = '001000000000005', Name = 'Acc 5.1'));
        System.assertEquals(new List<Boolean>{true, true, true}, db.updateMany(accsToUpdate), 'Expected successful Update');

        System.assertEquals(true, db.updateOne(new Account(Id = '001000000000001', Name = 'Acc 1.1')), 'Expected successful Update');
        System.assertEquals(2, db.query(Schema.SObjectType.Account.getSObjectType(), 'Name', new List<Object>{'Acc 3.1', 'Acc 4.1'}).size());
        
        // UPSERT
        final List<Account> accsToUpsert = new List<Account>();
        accsToUpsert.add(new Account(Id = '001000000000004', Name = 'Acc 4.1'));
        accsToUpsert.add(new Account(Id = '001000000000005', Name = 'Acc 5.1'));
        accsToUpsert.add(new Account(Id = '001000000000006', Name = 'Acc 6'));
        System.assertEquals(new List<Boolean>{true, true, true}, db.upsertMany(accsToUpsert), 'Expected successful UPSERT');
        System.assertEquals(3, db.query(Schema.SObjectType.Account.getSObjectType(), 'Name', new List<Object>{'Acc 4.1', 'Acc 5.1', 'Acc 6'}).size());

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
        System.assertEquals(0, db.query(Schema.SObjectType.Account.getSObjectType(), 'Name', new List<Object>{'Acc 1'}).size());
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
}
