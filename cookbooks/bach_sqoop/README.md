Overview
========

This cookbook installs Apache Sqoop and needed JDBC jars. The Sqoop packages come from Hortonworks via 'apt'.  JDBC jars are downloaded directly.

Requirements
============

This cookbook has been tested with Chef 11 and 12.

Recipes
=======

Only a default recipe is included.  The default recipe installs Sqoop, creates its library directory, and installs any JDBC jars to the library directory.

Attributes
==========

<ol>
  <li>node[:bach][:sqoop][:install_dir]<br/>
    <p>The Sqoop install directory.  Default: <tt>/usr/lib/sqoop</tt></p>
  </li>
  <li>node[:bach][:sqoop][:install_dir]<br/>
    <p>The Sqoop library directory, where JDBC jars will be installed. Default: <tt>/usr/lib/sqoop/lib</tt></p>
  </li>
  <li>node[:bach][:sqoop][:jdbc_jars]<br/>
    <p>This attribute is a hash.  The keys are the filenames for JDBC jars.  Each value is another hash, containing an 'url' key and a 'checksum' key.</p>
	<p>See <tt>attributes/default.rb</tt> for an example value.</p>
  </li>
</ol>
