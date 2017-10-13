**ApiManagement**

Sets up the API interfaces for the Azure platform which are published for use by remote services.  They
can publish data in a variety of formats; the format is requested by the caller.  Some of the formats available are:

* csv
* xml
* json
* rdf
* html
* tsv [(Tab-separated values)](http://en.wikipedia.org/wiki/Tab-separated_values)

The full list of formats can be seen when using an API.  For instance, viewing [Stephen Hammond](https://beta.parliament.uk/people/bpM8fJmB)'s entry on the WebSite
contains references to the fixed query APIs in the HTML:

* `<link href="https://api.parliament.uk/Live/fixed-query/person_by_id?person_id=bpM8fJmB" rel="alternate" type="text/turtle">`

The `type` parameters specify the format; similar lines show the other formats available.

Associated with APIs are policies governing their use.  Publicly facing APIs can have policies which:
* provide caching
* restrict their use to avoid an external DoS attack.

For internal use there are no such restrictions.