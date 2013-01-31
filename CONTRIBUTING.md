EPrints is Open Source software, which means the more you put in the greater the benefit for everyone. Contributions don't have to be source code: they can be answering questions on ep-tech, adding guidance to the Wiki or advocacy in your community.

If you wish to commission bespoke work please contact EPrints Services, http://www.eprints.org/.

## Contributing bug reports and other issues

If you have found a bug or have a general enquiry please check the archives and/or post a message on the ep-tech mailing list (http://mailman.ecs.soton.ac.uk/mailman/listinfo/eprints-tech).

If you open an Issue on github please provide as much information as possible:

* Attach screenshots for interface problems
* Apache server error log (make sure to include ssl if using https!)
* Environmental information such as EPrints version, database and operating system
* Classic bug-reporting: what you did, what you expected, what you actually got

## Contributing code changes

Github is a social development tool which is intended to make it easy to contribute changes to projects. There is extensive documentation available at https://help.github.com/.

The following is intended to give EPrints-specific notes on contributing core changes.

We intend to keep the EPrints core Copyright University of Southampton, which will allow us to re-license the software in the future. We can never revoke the existing LGPL/GPL version of EPrints (nor would we wish to) but we need the ability to release under different licenses e.g. for commercial partners.

As with all Open Source software you are free to "fork" and develop your own software based on EPrints, as long as it adheres with the license agreement (currently LGPL/GPL - see the source for details).

### What license do I need to submit my changes under?

If you are making changes to files copyrighted University of Southampton you need to assign the copyright in your contribution to University of Southampton. That covers anything in the software except for 3rd party modules bundled in perl_lib/ (see individual files for their licensing).

Fill out a CAA (individual or entity) located here:

https://github.com/eprints/eprints/raw/master/licenses/caa_individual.txt

https://github.com/eprints/eprints/raw/master/licenses/caa_entity.txt

In a **separate** pull request place your completed CAA in licenses/contributors/ (where the file name is your github username plus ".txt") and add your name to the list of contributors in AUTHORS.

You only need do this once.

If you do not wish to place your completed CAA in the source code please email it to support@eprints.org.
