#################################################################
#                                                               #
#  THis is an example file. Please save a copy of this file as  #
#                                                               #
#  [EPRINTS_ROOT]/archives/[ARCHIVEID]/cfg/cfg.d/recaptcha.pl   #
#                                                               #
#  or update the contents of that file if it already exisits.   #
#                                                               #
#################################################################
#
# This is a suggested list of things to do:
# 1. Register with ReCAPTCHA
# 2. Add keys to this file
# 3. Work out what you want to use a ReCAPTCHA on (example for requests and user registration below)
# 4. Update workflows (details below)
# 5. Test ([EPRINTS_ROOT]/bin/epadmin test ARCHIVEID)
# 6. Update ([EPRINTS_ROOT]/bin/epadmin update ARCHIVEID) NB no data is stored for recaptcha fields
# 7. Restart Apache
# 8. Test
#
#
# To use the ReCAPTCHA service you need to register at 
# https://www.google.com/recaptcha/admin
# 
# Enter the keys for your domain here:

$c->{recaptcha}->{public_key} = "PUBLIC_KEY";
$c->{recaptcha}->{private_key} = "PRIVATE_KEY";

# You may also want to tweak the amount of time your server will wait to get a response from the
# ReCAPTCHA server. This defaults to 5 seconds if not set here.
# $c->{recaptcha}->{timeout} = 10; 


# If you wish to test the ReCAPTCHA service, the following keys are provided,
# which always pass the test, but also display a warning on the ReCAPTCHA 
# form element. See:
# https://developers.google.com/recaptcha/docs/faq#id-like-to-run-automated-tests-with-recaptcha-v2-what-should-i-do
# for more details
#
#$c->{recaptcha}->{public_key} = "6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI";
#$c->{recaptcha}->{private_key} = "6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe";
#
#
# To add this to the user fields (for registrations):
$c->add_dataset_field( "user", {
	name => "captcha",
	type => "recaptcha",
});

# and/or add field to requests:
$c->add_dataset_field( "request", {
	name => "captcha",
	type => "recaptcha",
});

# Finally you have to add the field to the workflows - depending on which dataobjects you've enabled it for:
# 
# [EPRINTS_ROOT]/archives/[ARCHIVEID]/cfg/workflows/request/default.xml
# [EPRINTS_ROOT]/archives/[ARCHIVEID]/cfg/workflows/user/register.xml
#
# If the workflow file doesn't exist, you might be using the default version located in e.g.
#   [EPRINTS_ROOT]/lib/workflows/request/default.xml
# DO NOT edit this where it is (it will get overwritten when you upgrade EPrints). Instead, copy it to e.g.
#  [EPRINTS_ROOT]/archives/[ARCHIVEID]/cfg/workflows/request/default.xml
#
#  At the end of the appropriate workflow stage (e.g. 'main' for requests), add the following:
#  <component surround="None"><field ref="captcha" /></component>
#

