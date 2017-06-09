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
        final Id objId = (Id)obj.get('Id');
        if (null == objById) {
            objById = new Map<Id, SObject>();
            recordsByType.put(sobjectType, objById);
        } else if (objById.containsKey(objId)) {
            return false;
        }
        objById.put(objId, obj);

        return true;
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

    /**
     * query all previously added records of specific SObject Type
     */
    public QueryResult query(final Schema.SobjectType sobjectType) {
        return query(sobjectType, new Map<String, Object>());
    }

    /**
     * query all previously added records of specific SObject Type and immediately apply field/value filter
     * e.g. 
     *  query( Schema.SobjectType.Account.getSObjectType(), new Map<String, Object> {'Name' => 'Test Account', 'AnnualRevenue' => 123.45})
     */
    public QueryResult query(final Schema.SobjectType sobjectType, final Map<String, Object> keyValue) {
        System.debug('agX query ' +sobjectType+ '>> keyValue = ' + keyValue);
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
            System.debug('agX expected=' + expected);
            System.debug('agX actual=' + actual);
            if (expected != actual) {
                return false;
            }
        }
        return true;
    }

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
        
        public List<SObject> getCollection() {
            return null == collection ? new List<SObject>(): collection;
        }
        public Integer size() {
            return getCollection().size();
        }
        public Boolean isEmpty() {
            return getCollection().isEmpty();
        }

        /**
         * return only records where value of given field name has belongs ot list of filterValues
         * e.g. 
         *  filter( 'Name', new List<Object> {'Test Account 1', 'Test Account 2', 'Test Account XX'});
         */
        public QueryResult filter(final String fName, final List<Object> filterValues) {
            final List<SObject> resultRecords = new List<SObject>();
            for(SObject record : getCollection()) {
                for(Object value : filterValues) {
                    if (isMatch(record, new Map<String, Object>{fName => value})) {
                        resultRecords.add(record);
                    }
                }
            }
            return new QueryResult(db, resultRecords);
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