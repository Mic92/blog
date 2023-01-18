+++
title = "Gathering Crash Reports and User Feedback for Your Android App"
date = "2014-06-10"
slug = "2014/06/10/gathering-crash-reports-and-user-feedback-for-your-android-app"
Categories = []
+++

**tl;dr:** How-to use ACRA and a PHP-script for getting **fairly pretty
crash-reports and user-feedback via email** (without ugly Android email-Intents)

## Introduction

I'm the developer of
[OpenTraining](https://github.com/chaosbastler/opentraining), an open source
Android app for fitness training. I recently looked for a possibility to add a
simple feedback system to my app. There's an open source framework for crash
reports named [ACRA](https://github.com/ACRA) that I decided to use for both
crash reports and user feedback.

The Google Play Store offers a crash report system as well, but if you deploy
your app on multiple app stores you might want a central instance for collecting
crash reports. For user feedback many apps simply open an email-Intent but I
don't think this offers a good user experience.

This is how the user feedback dialog and the generated mail look like:

![Android feedback dialog and feedback mail](/downloads/android_feedback.jpg "Android feedback dialog and feedback mail")

Advantages:

- simple
- self-hosted
- good workflow for smaller projects
- only PHP required

Disadvantages:

- does not scale (e.g. if you have 50.000+ users)

If your project is pretty large you should consider another
[ACRA-backend](https://github.com/ACRA/acra/wiki/Backends). I tried some of
them, but as long as I get < 20 emails per week I'll use the PHP backend.

This How-to is based on [ACRA](https://github.com/ACRA) and
[ACRA-mailer](https://github.com/d-a-n/acra-mailer).

## How-To

The most important changes I had to apply to my project for adding the
feedback-feature can be seen in
[this commit](https://github.com/chaosbastler/opentraining/commit/19e52b76b8370e78b9d67e4110d04463d1cd2ad6)
on GitHub (but there have been some more commits concerning ACRA).

### 1. Add ACRA to your project

- Open your Eclipse project
- Add the file
  [acra-4.X.Y.jar](http://search.maven.org/remotecontent?filepath=ch/acra/acra/4.5.0/acra-4.5.0.jar)
  to the libs folder
- Right-click on the jar file -> add to build path

If you have any problems with this step have a look at the
[ACRA documentation](https://github.com/ACRA/acra/wiki/BasicSetup). There's also
a description for
[Gradle integration](https://github.com/ACRA/acra/wiki/AdvancedUsage#integrating-as-a-dependency-with-maven-or-gradle).

### 2. Use the ACRA library

Create a new class that extends Application:

    import org.acra.*;
    import org.acra.annotation.*;

    import android.app.Application;


    @ReportsCrashes(
        formKey = "" // This is required for backward compatibility but not used
     )


    public class YourApplication extends Application{

    	@Override
         public void onCreate() {
             super.onCreate();

             // The following line triggers the initialization of ACRA
             ACRA.init(this);
             ACRA.getErrorReporter().setReportSender(new ACRACrashReportMailer()); // default crash report sender
    	}


    }

Open the android manifest editor (AndroidManifest.xml)

- In the Application tab, click on the Browse button next to the Name field
- Select your newly created Application class

Make sure that your application requests the permission
**'android.permission.INTERNET'**.

### 3. Add ReportSender

I use 2 different implementations of ReportSender:

- one to report crashes:
  [ACRACrashReportMailer](https://github.com/chaosbastler/opentraining/blob/71db0726607885fb815e230886dcebeb93817371/app/src/de/skubware/opentraining/activity/acra/ACRACrashReportMailer.java)
- one to report feedback:
  [ACRAFeedbackMailer](https://github.com/chaosbastler/opentraining/blob/71db0726607885fb815e230886dcebeb93817371/app/src/de/skubware/opentraining/activity/acra/ACRAFeedbackMailer.java)

The crash reporter sends nearly all data that's available, the feedback reporter
sends the user message, the date and the app version. Add both to your project.

Remember to change the 'BASE_URL'. Use HTTPS if your server supports it (mine
doesn't).

### 4. Add PHP scripts

There are 2 PHP scripts as well:

- one to report crashes:
  [acra_crash.php](https://github.com/chaosbastler/opentraining/blob/71db0726607885fb815e230886dcebeb93817371/server/acra_crash.php)
- one to report feedback:
  [acra_feedback.php](https://github.com/chaosbastler/opentraining/blob/71db0726607885fb815e230886dcebeb93817371/server/acra_feedback.php)

You will also need the
[mail template](https://github.com/chaosbastler/opentraining/blob/71db0726607885fb815e230886dcebeb93817371/server/mail_template.txt).
Change the destination email and add the files to the webspace/server of your
choice (e.g. [uberspace](https://uberspace.de/)). If you want you can change the
"shared_secret", but remember to do this in the Java class as well.

### 5. Test receiving feedback

Now you should have a try and test sending feedback to yourself:

    ACRA.getErrorReporter().setReportSender(new ACRAFeedbackMailer());
    ACRA.getErrorReporter().putCustomData("User message", "Some Text here");
    ACRA.getErrorReporter().handleSilentException(new NullPointerException("Test"));

If this works you need a suitable spot for your user feedback. In most cases a
[dialog](https://github.com/chaosbastler/opentraining/blob/71db0726607885fb815e230886dcebeb93817371/app/src/de/skubware/opentraining/activity/create_workout/SendExerciseFeedbackDialogFragment.java)
should be fine.

Consider to write your
[own class(es)](https://github.com/chaosbastler/opentraining/blob/71db0726607885fb815e230886dcebeb93817371/app/src/de/skubware/opentraining/activity/acra/RequestExerciseUpdate.java)
that extend(s) Exception. Your PHP script could do further processing with this
information.

## Ideas for further improvements

### Improve the email formatting

As you have a server-side script it is very easy to change the formatting of the
emails. Highlighting the user comments or the type of exception may be a good
first step.

### Usage for larger projects

With the use of two different implementations of ReportSender it is also
possible to use email only for sending feedback and send crash reports to
another backend that is better suited for bug tracking. For larger projects this
approach is recommended.

_by Christian Skubich_

eMail: christian@skubware.de

Twitter: [@chaosbastler](https://twitter.com/chaosbastler)
