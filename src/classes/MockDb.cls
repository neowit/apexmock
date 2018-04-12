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
 *	@description:
 *	basic in-memory DB implementation which can be used to replace calls to real SFDC DB in unit tests
 *
 */
public class MockDb {
    final static Map<String, Schema.SObjectType> OBJ_TYPE_BY_NAME = new  Map<String, Schema.SObjectType>();
    static {
        Map<String, Schema.SObjectType> typeByName = Schema.getGlobalDescribe();
        for(String typeName : typeByName.keySet()) {
            OBJ_TYPE_BY_NAME.put(typeName.toLowerCase(),  typeByName.get(typeName));
        }
    }
    final Map<Schema.SobjectType, Map<Id, SObject>> recordsByType = new Map<Schema.SobjectType, Map<Id, SObject>>();

    public List<Boolean> updateMany(final List<SObject> objs) {
        final List<Boolean> results = new List<Boolean>();
        if (null == objs || objs.isEmpty()) {
            return results;
        }
        Schema.SobjectType sobjectType = objs[0].getSObjectType();
        final Map<Id, SObject> objById = recordsByType.get(sobjectType);
        if (null == objById) {
            return results;
        }
        for(Sobject obj : objs) {
            results.add(updateOne(obj));
        }
        return results;
    }
    
    public Boolean updateOne(final SObject obj) {
        final Map<Id, SObject> objById = recordsByType.get(obj.getSObjectType());
        final Id objId = (Id)obj.get('Id');
        if (null == objById || !objById.containsKey(objId)) {
            return false;
        }

        objById.put(objId, obj);

        return true;
    }
    
    public List<Boolean> insertMany(final List<SObject> objs) {
        final List<Boolean> results = new List<Boolean>();
        if (null == objs || objs.isEmpty()) {
            return results;
        }
        for(Sobject obj : objs) {
            results.add(insertOne(obj));
        }
        return results;
    }
    
    public Boolean insertOne(final SObject obj) {
        final Schema.SobjectType sobjectType = obj.getSObjectType();
        Map<Id, SObject> objById = recordsByType.get(sobjectType);
        Id objId = (Id)obj.get('Id');
        if (null == objId) {
            objId = getNewId(sobjectType);
            obj.put('Id', objId);
        }

        if (null == objById) {
            objById = new Map<Id, SObject>();
            recordsByType.put(sobjectType, objById);
        } else if (objById.containsKey(objId)) {
            System.assert(false, 'Duplicate Id: '+objId+' for sobjectType=' + sobjectType + ' clashes with previously inserted value. Consider revising manually created test Ids for this object type');
            return false;
        }
        objById.put(objId, obj);

        return true;
    }
    
    private Id getNewId(final Schema.SobjectType sobjectType) {
        Map<Id, SObject> objById = recordsByType.get(sobjectType);
        Integer nextIndex = (null == objById ? 0 : objById.size()) + 1000000; // test Ids start with 1 Million
        final String keyPrefix = sobjectType.getDescribe().getKeyPrefix();
        String indexStr = String.valueOf(nextIndex) ;
        Integer padSize = 15 - keyPrefix.length();
        return keyPrefix + indexStr.leftPad(padSize, '0');
    }

    public List<Boolean> upsertMany(final List<SObject> objs) {
        final List<Boolean> results = new List<Boolean>();
        if (null == objs || objs.isEmpty()) {
            return results;
        }
        for(Sobject obj : objs) {
            results.add(upsertOne(obj));
        }
        return results;
    }
    
    public Boolean upsertOne(final SObject obj) {
        final Schema.SobjectType sobjectType = obj.getSObjectType();
        Map<Id, SObject> objById = recordsByType.get(sobjectType);
        final Id objId = (Id)obj.get('Id');
        if (null == objById) {
            objById = new Map<Id, SObject>();
            recordsByType.put(sobjectType, objById);
        }             
        objById.put(objId, obj);

        return true;
    }
    
    // this method is not efficient because cycles through all stored object types
    // but for use in unit tests *only* it should be OK
    public void deleteMany(final Set<Id> ids) {
        for(Map<Id, SObject> objectById : recordsByType.values()) {
            objectById.keySet().removeAll(ids);
        }
    }

    /**
     * query all previously added records of specific SObject Type
     */
    public QueryResult query(final String sobjectType) {
        return query(findSobjectType(sobjectType));
    }
    public QueryResult query(final Schema.SobjectType sobjectType) {
        return query(sobjectType, new Map<String, Object>());
    }
    
    private static  Schema.SobjectType findSobjectType(final String sobjectType) {
        final Schema.SobjectType objType = OBJ_TYPE_BY_NAME.get(sobjectType.toLowerCase());
        System.assertNotEquals(null, objType, 'SObjectType not found  by name: ' + sobjectType);
        return objType;
    }

    /**
     * query all previously added records of specific SObject Type and immediately apply field/value filter
     * e.g. 
     *  query( Schema.SobjectType.Account.getSObjectType(), new Map<String, Object> {'Name' => 'Test Account', 'AnnualRevenue' => 123.45})
     */
    public QueryResult query(final String sobjectType, final Map<String, Object> keyValue) {
        return query(findSobjectType(sobjectType), keyValue);
    }
    public QueryResult query(final Schema.SobjectType sobjectType, final Map<String, Object> keyValue) {
        final Map<Id,SObject> recordsById = recordsByType.get(sobjectType);
        if (null == recordsById) {
            return new QueryResult(this, new List<SObject>());
        }

        final QueryResult qRes = new QueryResult(this, recordsById.values());
        return qRes.filter(keyValue);
    }


    private static Boolean isMatch(final SObject obj, final Map<String, Object> keyValue) {
        for(String fName : keyValue.keySet()) {
            Object expected = keyValue.get(fName);
            Object actual = obj.get(fName);
            if (expected != actual) {
                return false;
            }
        }
        return true;
    }

    /**
     * return value of specific field from each SObject from given collection
     */
    public static List<Object> collectValues(final List<SObject> objs, final String fName) {
        final List<Object> values = new List<Object>();
        for(SObject obj : objs) {
            Object value = obj.get(fName);
            if (null != value) {
                values.add(value);
            }
        }
        return values;
    }
    
    /**
     * set values of multiple fields on SObject in one go 
     */
    public static SObject setValues(final SObject obj, final Map<String, Object> keyValue) {
        for(String fName : keyValue.keySet()) {
            Object value = keyValue.get(fName);
            obj.put(fName, value);
        }
        return obj;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////
    //          Query Result
    //////////////////////////////////////////////////////////////////////////////////////////////////
    public class QueryResult {
        final MockDb db;
        final List<SObject> collection;

        public QueryResult(final MockDb db, final List<SObject> records) {
            this.db = db;
            this.collection = records;
        }
        
        /**
         * currently held collection of SObject-s
         * - similar to List returned by: [select ... from ObjectType]
         */
        public List<SObject> getCollection() {
            return null == collection ? new List<SObject>(): collection;
        }
        /**
         * if collection is not empty then return first element
         */
        public SObject head {
            private set; 
            get {
                return null != collection && !collection.isEmpty() ? collection[0] : null;
            }
        }

        /**
         * unlike getCollection() this methods returns a list of values of specific field from result collection
         * ex: if we had a query: [select Id, Name from Account]
         * then getCollectionOf('Name') will return List of account names
         */
        public List<Object> getCollectionOf(final String fName) {
            final List<Object> resCollection = new List<Object>();
            for (SObject rec: getCollection()) {
                resCollection.add(rec.get(fName));
            }
            return resCollection;
        }
        /**
         * dump a set of values of specific field from result collection
         * ex: if we had a query: [select Id, Name from Account]
         * then getSetOfIds('AccountId') will populate provided resultSet with a Set of account Ids
         */
        public Set<Id> getSetOfIds(final String fName) {
            final Set<Id> resultSet = new Set<Id>();
            for (SObject rec: getCollection()) {
                resultSet.add((Id)rec.get(fName));
            }
            return resultSet;
        }
        
        /**
         *  when called as getMapById('Id') the result is similar to: 
         *      new Map<Id, SObject>([select ... from ObjectType])
         */
        public Map<Id, SObject> getMapById(final String fName) {
            final Map<Id, SObject> resultMap = new Map<Id, SObject>();
            for (SObject rec: getCollection()) {
                resultMap.put((Id)rec.get(fName), rec);
            }
            resultMap.remove(null);
            return resultMap;
        }
        /**
         * similar to getMapOfIds, except the key is String field
         */
        public Map<String, SObject> getMapByString(final String fName) {
            final Map<String, SObject> resultMap = new Map<String, SObject>();
            for (SObject rec: getCollection()) {
                resultMap.put((String)rec.get(fName), rec);
            }
            resultMap.remove(null);
            return resultMap;
        }
        
        public Integer size() {
            return getCollection().size();
        }
        public Boolean isEmpty() {
            return getCollection().isEmpty();
        }

        /**
         * return only records where value of given field name belongs ot list of filterValues
         * e.g. 
         *  filter( 'Name', new List<Object> {'Test Account 1', 'Test Account 2', 'Test Account XX'});
         */
        public QueryResult filter(final String fName, final Set<Id> filterValues) {
            return filter(fName, new List<Id>(filterValues));
        }
        public QueryResult filter(final String fName, final Set<String> filterValues) {
            return filter(fName, new List<String>(filterValues));
        }
        public QueryResult filter(final String fName, final List<Object> filterValues) {
            final List<SObject> resultRecords = new List<SObject>();
            final Set<Object> uniqueValues = new Set<Object>(filterValues);
            for(SObject record : getCollection()) {
                for(Object value : uniqueValues) {
                    if (isMatch(record, new Map<String, Object>{fName => value})) {
                        resultRecords.add(record);
                    }
                }
            }
            return new QueryResult(db, resultRecords);
        }

        /**
         * return only records where value of given field name equals filterValue
         * e.g. 
         *  filter( 'Name', 'Test Account 1');
         */
        public QueryResult filter(final String fName, final String filterValue) {
            return filter(fName, new List<String>{filterValue});
        }
        public QueryResult filter(final String fName, final Id filterValue) {
            return filter(fName, new List<Id>{filterValue});
        }
        public QueryResult filter(final String fName, final Decimal filterValue) {
            return filter(fName, new List<Decimal>{filterValue});
        }
        public QueryResult filter(final String fName, final Boolean filterValue) {
            return filter(fName, new List<Boolean>{filterValue});
        }
        
        /**
         * apply field/value filter to QueryResult
         * return only records where all field/value pairs have values matching to keyValue map
         * e.g. 
         *  filter( new Map<String, Object> {'Name' => 'Test Account', 'AnnualRevenue' => 123.45})
         */
        public QueryResult filter(final Map<String, Object> keyValue) {

            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                if (isMatch(record, keyValue)) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);
        }

        ///////////////// Date Specific //////////////////////////////////
        public QueryResult greaterThan(final String fName, final Date val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                Date objVal = (Date)record.get(fName);
                if (null != objVal && objVal > val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);

        }

        public QueryResult greaterOrEqual(final String fName, final Date val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                Date objVal = (Date)record.get(fName);
                if (null != objVal && objVal >= val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);
        }

        public QueryResult lessThan(final String fName, final Date val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                Date objVal = (Date)record.get(fName);
                if (null != objVal && objVal < val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);

        }

        public QueryResult lessOrEqual(final String fName, final Date val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                Date objVal = (Date)record.get(fName);
                if (null != objVal && objVal <= val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);
        }

        ///////////////// DateTime Specific //////////////////////////////////
        public QueryResult greaterThan(final String fName, final DateTime val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                DateTime objVal = (DateTime)record.get(fName);
                if (null != objVal && objVal > val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);

        }

        public QueryResult greaterOrEqual(final String fName, final DateTime val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                DateTime objVal = (DateTime)record.get(fName);
                if (null != objVal && objVal >= val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);
        }

        public QueryResult lessThan(final String fName, final DateTime val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                DateTime objVal = (DateTime)record.get(fName);
                if (null != objVal && objVal < val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);

        }

        public QueryResult lessOrEqual(final String fName, final DateTime val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                DateTime objVal = (DateTime)record.get(fName);
                if (null != objVal && objVal <= val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);
        }

        ///////////////// Decimal Specific //////////////////////////////////
        public QueryResult greaterThan(final String fName, final Decimal val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                Decimal objVal = (Decimal)record.get(fName);
                if (null != objVal && objVal > val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);

        }

        public QueryResult greaterOrEqual(final String fName, final Decimal val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                Decimal objVal = (Decimal)record.get(fName);
                if (null != objVal && objVal >= val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);
        }

        public QueryResult lessThan(final String fName, final Decimal val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                Decimal objVal = (Decimal)record.get(fName);
                if (null != objVal && objVal < val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);

        }

        public QueryResult lessOrEqual(final String fName, final Decimal val) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                Decimal objVal = (Decimal)record.get(fName);
                if (null != objVal && objVal <= val) {
                    resultRecords.add(record);
                }
            }
            return new QueryResult(db, resultRecords);
        }

    }
}