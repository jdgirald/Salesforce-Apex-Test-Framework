/**
 @Name: c_TestFactory.cls
 @TestedBy: Implementing in a test class
 @Description: Registry of Business Objects 
 - Update here when creating a new object for use in tests to allow the factory to map and create sObjects and sets of sObjects

 @Usage: 
 1) Your test class should inherit from here to access context, constants and the factory methods "Make" and "Run"
 2) To create a new object template ii) create a new 'maker' Class inheriting from c_TestFactoryMaker 
 3) Build out using the "Make" method c_Testfactory.make(my business object [,using my sObject as a base]);
 
 This class should not need to be edited. Methods:
  0. Context values for the tests
  1. Make methods - 'Make' objects in memory 
  3. Automation methods  - 'Run' commits the objects in memory in the database
  4. Test Context. Set from Custom Metadata c_TestSettings__Mtd. Public so they may be overridden in code.
  5. Utility methods 

 @History
  VERSION     AUTHOR           DATE            DETAIL
  2.0         Matt Evans       8/6/2020        Prototyping removal of Entity System. Merge wityh Automation Class
*/

public virtual class c_TestFactory {

    /**
     * Test Context
     * ------------
     * Pseudo Constants (therefore UPPERCASE)
     * Set from Custom Metadata c_TestSettings__Mtd. 
     * Public so they may be overridden in code. 
     * Provides common context for the objects, such as Country, 
     * and a switch Bulkify Tests to define how much data to produce.
    **/
    static c_TestSettings__mdt defaultContext;
    public static Boolean BULKIFY_TESTS {
        get {
            if (BULKIFY_TESTS==null) {
                setDefaultContext(); 
                BULKIFY_TESTS =  defaultContext.BULKIFY_TESTS__c;
            }
            return BULKIFY_TESTS;
        } 
        set{BULKIFY_TESTS = value;}
    }
    public static String COUNTRY_CODE {
        get {
            if (COUNTRY_CODE==null) {
                setDefaultContext(); 
                COUNTRY_CODE =  defaultContext.COUNTRY_CODE__c;
            }
            return COUNTRY_CODE;
        } 
        set{COUNTRY_CODE = value;}
    }
    public static String COUNTRY_NAME {
        get {
            if (COUNTRY_NAME==null) {
                setDefaultContext(); 
                COUNTRY_NAME =  defaultContext.COUNTRY_NAME__c;
            }
            return COUNTRY_NAME;
        } 
        set{COUNTRY_NAME = value;}
    }
    public static String TIMEZONE_SID_KEY {
        get {
            if (TIMEZONE_SID_KEY==null) {
                setDefaultContext(); 
                TIMEZONE_SID_KEY =  defaultContext.TIMEZONE_SID_KEY__c;
            }
            return TIMEZONE_SID_KEY;
        } 
        set{TIMEZONE_SID_KEY = value;}
    }
    public static String LANGUAGE_LOCALE_KEY {
        get {
            if (LANGUAGE_LOCALE_KEY==null) {
                setDefaultContext(); 
                LANGUAGE_LOCALE_KEY =  defaultContext.LANGUAGE_LOCALE_KEY__c;
            }
            return LANGUAGE_LOCALE_KEY;
        } 
        set{LANGUAGE_LOCALE_KEY = value;}
    }
    public static String LOCALE_SID_KEY {
        get {
            if (LOCALE_SID_KEY==null) {
                setDefaultContext(); 
                LOCALE_SID_KEY =  defaultContext.LOCALE_SID_KEY__c;
            }
            return LOCALE_SID_KEY;
        } 
        set{LOCALE_SID_KEY = value;}
    }
    public static String CURRENCY_ISO_CODE {
        get {
            if (CURRENCY_ISO_CODE==null) {
                setDefaultContext(); 
                CURRENCY_ISO_CODE =  defaultContext.CURRENCY_ISO_CODE__c;
            }
            return CURRENCY_ISO_CODE;
        } 
        set{CURRENCY_ISO_CODE = value;}
    }
    public static String EMAIL_ENCODING_KEY {
        get {
            if (EMAIL_ENCODING_KEY==null) {
                setDefaultContext(); 
                EMAIL_ENCODING_KEY =  defaultContext.EMAIL_ENCODING_KEY__c;
            }
            return EMAIL_ENCODING_KEY;
        } 
        set{EMAIL_ENCODING_KEY = value;}
    }
    public static Datetime NOW = System.now();

    public static void setDefaultContext()
    {
        if (defaultContext==null) {
            c_TestSettings__mdt [] activeSettings = [SELECT MasterLabel, 
                                   QualifiedApiName, Created__c, Active__c,
                                   BULKIFY_TESTS__c,
                                   COUNTRY_CODE__c, COUNTRY_NAME__c, CURRENCY_ISO_CODE__c, EMAIL_ENCODING_KEY__c, 
                                   LANGUAGE_LOCALE_KEY__c, LOCALE_SID_KEY__c, 
                                   TIMEZONE_SID_KEY__c
                                   FROM c_TestSettings__mdt  
                                   where Active__c = TRUE
                                   Order By Created__c DESC limit 1];
    
            if (!activeSettings.IsEmpty()) {
                defaultContext = activeSettings[0];
            }
        }
    }

    /**
    * Building objects using the "make" method
    * - Call the Make method in your test class to build an object
    * - Factory takes the result and adds it to a consolidated map grouped by object Type (and ordered in that way too)
    * - Creates and returns one or more sObject records based on default values, merged with any sObject passed
    * - Every sObject created by the class is kept in a list, so that the factory can check through them to group DML and automate the insert process
    **/

    // Track the components  built
    static Map<Type, c_TestFactoryObject> objectsByType = new Map<Type, c_TestFactoryObject>();
    static List<Type> objectOrder = new List<Type>(); //Keep the order of the Map managed as FIFO (as Maps are unordered by definition)

    // Method "MAKE" / tell the factory to build an object of a certain type
    public static sObject make(Type templateClass) {
        return make(templateClass, null);
    }

    // Method "MAKE" / index the objects by type and run the make() method on the interface
    public static sObject make(Type templateClass, sObject sourceObject) {
        c_TestFactoryObject businessObject;

        if (!objectsByType.containsKey(templateClass)) {
            businessObject = (c_TestFactoryObject) templateClass.newInstance();
            objectOrder.add(templateClass);
            objectsByType.put(templateClass, businessObject);
        } else {
            businessObject = objectsByType.get(templateClass);
        }

        return businessObject.make(sourceObject);
    }

    // Get list of sObjects by type
    public static sObject[] getSObjects(Type objectType) {
        return objectsByType.get(objectType).get();
    }

    /**
    * Run the factory - automating production of entities
    **/

    // Method "RUN"
    //  - Execute the factory context and run the DML. Default behaviour is to flush the list of records after inserting

    // Run with Clear flag set to TRUE
    // - Result is a list that gets flushed and cleared after execution. This is default behaviour
    // - flushing them reduces the amount of working memory, and reduces the amount of repeated DML
    public static void run() {
        run(TRUE);     
    }

    // Run with Clear flag set to FALSE
    // - run but dont flush the arrays of objects after creating them. Beware of running twice!
    public static void runAndKeepContext() {
        run(FALSE); 
    }

    // Method "RUN" with overload option
    // - Create each set of business objects in order the objects are initially created
    public static void run(Boolean clearObjects) {
        for (Type objectType : objectOrder) {
            System.Debug(LoggingLevel.INFO,'@@ Create TYPE '+objectType+ ' size '+objectsByType.get(objectType).get().size());
            if (objectsByType.get(objectType).get().size()>0) {
                createEntity(objectType, clearObjects);
            }
        }
    }

    // Create Objects
    //  - Get the sObjects list from each Business Object and insert them to the database in order
    //  - For composite objects ensure mixed sObject types are ordered so that parents precede children
    //  - Ex. Pseudo code: [Account 1 followed by the account's Contacts 1,2,3,4; then Account 2 and child Contacts 6,7,8; then Cases; etc.]

    static void createEntity(Type objectType, Boolean clearObjects) {
        System.debug(LoggingLevel.INFO,'@@ START: Test Factory Create Type '+ objectType +' : clear objects:'+clearObjects+'@@');
        System.debug(LoggingLevel.INFO,'@@ CPU time '+System.Limits.getCpuTime());

        // Compile all the sObjects created by the Business Object's maker class
        // - These where generated every time the 'make' method was run.
        sObject[] objs = new List<sObject>();
        objs.addAll(objectsByType.get(objectType).get());

        // Upsert the sobject lists in order, allowing for ID's and external ID's to be created in each transaction
        // - DML should not be in a loop ;) however it is limited by TYPE and therefore this will not be called more than the number of sObject types being created
        // - The ambition of the framework is to REDUCE the amount of DML used creating objects.
        List<String> createOrder = new List<String>();

        Map<String, sObject[]> collections_INSERT = new map<String, sObject[]>();
        Map<String, sObject[]> collections_UPDATE = new map<String, sObject[]>();

        sortAndLinkSObjects(objs, createOrder, collections_INSERT, collections_UPDATE);

        for (String name : createOrder) {
            if (collections_UPDATE.containsKey(name) && collections_UPDATE.get(name).size()>0) {
                update (collections_UPDATE.get(name));
            }
            if (collections_INSERT.containsKey(name) && collections_INSERT.get(name).size()>0) {
                insert (collections_INSERT.get(name));
            }
        }

        // Clear the list of sObject records on the Business Object
        if (clearObjects) {
            objectsByType.get(objectType).clear();
        }

        System.debug(LoggingLevel.INFO,'@@ END: Test Factory Create Type '+ objectType +' @@');
    }


    /**
    * Utility methods 
    * 1. Map relational fields
    * 2. Sort and Link sObjects
    **/

    // Map relational fields 
    // - Map example for Asset with several relationship fields of the same type: Asset => [Account1__c => Account1__r, Account2__c => Account2__r etc.]
    static Map<SObjectType, Map<String, String>> objectRelationalFieldMap = new Map<SObjectType, Map<String, String>>();
    static Map<String, String> setRelationalFieldMap(sObject o) {
        SObjectType sObjectType = o.getSObjectType();

        // Check we need to build the map for this object
        if (!objectRelationalFieldMap.containsKey(sObjectType)) {
            
            // Get the field name and the relational field name ex. field with name "AccountId" on Contact has relationalfield name "Account"
            Map<String, String> fieldNameToRelationshipName = new Map<String,String>();
            DescribeSObjectResult res = sObjectType.getDescribe();
                
            // Field info to cache
            for(Schema.SobjectField f : res.fields.getMap().Values()) {    

                // Only get relation fields (Loopup and master relations)       
                if (f.getDescribe().getReferenceTo().size()>0 && f.getDescribe().getRelationshipName()!=null) {

                    String fieldName = f.getDescribe().getName();
                    String relationshipName = f.getDescribe().getRelationshipName();
                    fieldNameToRelationshipName.put(fieldName, relationshipName);
                }
            }
            
            // Store only necessary fields in the map
            objectRelationalFieldMap.put(sObjectType, fieldNameToRelationshipName); 
        }
        return objectRelationalFieldMap.get(sObjectType);
    }
    static Map<String, String> getRelationalFieldMap(SObjectType sObjectType) {
        return objectRelationalFieldMap.get(sObjectType);
    }

    // Sort the list of sobject record by Type, in order of discovery (FIFO) into Insert or Update, and also attempts to create relationships to existing entities with ID's
    // -The method will map any relationships found, and attempt to link any valid relations, ex. a Contact to an Account in the list
    // -It will also use the Tokens to create a 'create order' list, so that records can be inserted based on the order of their insert into the list, which is important for dependent relationships.
    public static void sortAndLinkSObjects(sObject[] objs, List<String> createOrder, Map<String, sObject[]> collections_INSERT, Map<String, sObject[]> collections_UPDATE) {
 
        // Speed up the list by indexing relation field map by sObjects invovled
        // - This is very fast, but will we get different SObject types in the class? TODO: Yes, it's possible, however executing run() to flush the cashe fixes the problem
        Set<String> sObjectTokens = new Set<String>();
        for (sObject o : objs) {
            setRelationalFieldMap(o);
        }

        for (sObject o : objs) {
            // While looping over each record, we will inspect the relationship fields to dynamically assign ID's from any sObject
            // that the template joined (Ex. assign an AccoutId from an sObject on the Account field on Contact, or a __r reference)
            // This allows us to set sObjects to be assigned to reference fields when building out composite objects
            SObjectType objectType = o.getSObjectType();
            Map<String,String> relationalFieldMap = getRelationalFieldMap(objectType);
            if (relationalFieldMap!=null) {
                for(String fieldName : relationalFieldMap.keySet()) {
                    String relationshipName = relationalFieldMap.get(fieldName);
                    sObject relationshipObj = o.getSObject(relationshipName);
                    if (relationshipObj!=null && relationshipObj.id!=null) {
                        System.debug(LoggingLevel.INFO, '@@ Sobject in Relationship field '+relationshipName+' is assigning ' + fieldName+' with value '+relationshipObj.id);
                        o.put(fieldName,relationshipObj.id);
                    }
                }
            }
            
            // Now sort the records into UPDATE or INSERT DML, storing with object name as key
            String name = objectType.getDescribe().getName();
            if (o.get('Id')!=null)
            {
                if (!collections_UPDATE.containsKey(name)) {
                    createOrder.add(name);
                }

                sObject[] objectsByType = collections_UPDATE.containsKey(name) ? collections_UPDATE.get(name) : new List<sObject>();
                objectsByType.add(o);

                collections_UPDATE.put(name, objectsByType);
            } else {
                if (!collections_INSERT.containsKey(name)) {
                    createOrder.add(name);
                }

                sObject[] objectsByType = collections_INSERT.containsKey(name) ? collections_INSERT.get(name) : new List<sObject>();
                objectsByType.add(o);

                collections_INSERT.put(name, objectsByType);
            }
        }
    }

    /**
    * Exception Class
    */

    public class TestFactoryException extends Exception {}
//*/
}