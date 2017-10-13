**ApiManagement**

Sets up the API interfaces for the Azure platform.  APIs are published for use by remote services.  APIs
can publish data in a variety of formats which is requested by the caller.  A few of the formats available are:

* csv
* xml
* json
* rdf
* html
* tab-separated-values

The full list of supported formats can be queried from the APIs.

Associated with APIs are policies to govern their use; publicly facing APIs are governed by a policies to
provide a caching option or restrict their use to avoid a DoS attack while for internal use access can be more unrestricted.
