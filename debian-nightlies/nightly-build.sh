#!/bin/bash
set -e

# Do mapnik nightly builds
# Author: Robert Coup <robert@coup.net.nz>
# License: GPL-2+

# Branches to build
# branch keys here should match the build directory structure (./foo/svn/, ./foo/debian/)
# branch values are the latest official release from the branch
declare -A BRANCHES
BRANCHES["trunk"]="2" # is <2.0.0 when it actually comes along
BRANCHES["0.7.x"]="0.7.2"

# PPA names, keys are branches
declare -A PPAS
PPAS["trunk"]="ppa:mapnik/nightly-trunk"
PPAS["0.7.x"]="ppa:mapnik/nightly-0.7"

# Package names, keys are branches
declare -A PACKAGES
PACKAGES["trunk"]="mapnik2"
PACKAGES["0.7.x"]="mapnik"

# Ubuntu Distributions to build (space-separated)
# TODO: different dists per branch?
DISTS="lucid maverick"

# Build signing info...
GPGKEY=80B52FF1
DEBFULLNAME="Robert Coup (Mapnik Nightly Builds)"
DEBEMAIL="robert+mapniknightly@coup.net.nz"

######### Shouldn't need to edit anything past here #########

# parse command line opts
OPT_DRYRUN=
OPT_FORCE=
OPT_CLEAN=
while getopts ":fnc" OPT; do
    case $OPT in
        c)
           OPT_CLEAN=1
           ;;
        n)
           OPT_DRYRUN=1
           ;;
        f)
           OPT_FORCE=1
           ;;
        \?)
            echo "Usage: $0 [-f] [-n] [-c]" >&2
            echo "  -n   Skip the PPA upload & saving changelog." >&2
            echo "  -f   Force a build, even if the script doesn't want to. You may need to " >&2
            echo "       clean up debs/etc first." >&2
            echo "  -c   Delete archived builds. Leaves changelogs alone." >&2
            exit 2
            ;;
    esac
done

if [ ! -z $OPT_CLEAN ]; then
    # delete old archives
    for BRANCH in "${!BRANCHES[@]}"; do
        PACKAGE="${PACKAGES[$BRANCH]}"
        echo -e "\n*** Branch $BRANCH (${PACKAGE})"
        echo "rm -rvI \"${BRANCH}\"/${PACKAGE}_*"
        rm -rvI "${BRANCH}"/${PACKAGE}_*
    done
    exit 0
fi


DATE=$(date +%Y%m%d)
DATE_REPR=$(date -R)

for BRANCH in "${!BRANCHES[@]}"; do
    RELEASE_VERSION="${BRANCHES[$BRANCH]}"
    PACKAGE="${PACKAGES[$BRANCH]}"
    PPA="${PPAS[$BRANCH]}"
    echo -e "\n*** Branch $BRANCH (${PACKAGE})"

    pushd "$BRANCH"
    svn up svn/
    REV="$(svn info svn/ | grep 'Last Changed Rev' | awk -F': ' '{ print $2 }')"
    REV_PREV=$(cat prev.rev)
    echo "Previous revision was ${REV_PREV}"

    # Shall we build or not ? 
    if [ "$REV" == "${REV_PREV}" ]; then
        echo "No need to build!"
        if [ -z "$OPT_FORCE" ]; then
            popd
            continue
        fi
        echo "> ignoring..."
        CHANGELOG="  * : No changes"
    else
        # convert svn changelog into deb changelog.
        # strip duplicate blank lines too
        REV_PREV2=$(echo "$REV_PREV" | awk '{print $1+1}')
        CHANGELOG="$(svn log -r $REV_PREV2:$REV --stop-on-copy svn/ | ../svncl2deb.sh | cat -s)"
    fi

    BUILD_VERSION="${RELEASE_VERSION}+dev${DATE}.svn${REV}"

    SOURCE="${PACKAGE}_${BUILD_VERSION}"
    ORIG_TGZ="${PACKAGE}_${BUILD_VERSION}.orig.tar.gz"
    echo "Building orig.tar.gz ..."
    svn export -q svn/ $SOURCE
    tar czf $ORIG_TGZ "${SOURCE}/"
    rm -rf $SOURCE

    echo "Build Version ${BUILD_VERSION}"
    for DIST in $DISTS; do
        echo "Building $DIST ..."
        DIST_VERSION="${BUILD_VERSION}-1~${DIST}1"

        # start with a clean export
        tar xzf $ORIG_TGZ
        # add the debian/ directory
        rsync -a debian $SOURCE

        # update the changelog
        # urgency=medium gets us up the Launchpad queue a bit...
        cat >$SOURCE/debian/changelog <<EOF
${PACKAGE} (${DIST_VERSION}) ${DIST}; urgency=medium

${CHANGELOG}

 -- ${DEBFULLNAME} <${DEBEMAIL}>  ${DATE_REPR}

EOF
        # append previous changelog
        if [ -f $DIST.changelog ]; then
            cat $DIST.changelog >>$SOURCE/debian/changelog
        fi

        pushd $SOURCE
        echo "Actual debuild time..."
        # build & sign the source package
        debuild -S -k${GPGKEY}

        # woohoo, success!
        popd

        # send to ppa
        echo "Sending to PPA..."
        if [ -z "$OPT_DRYRUN" ]; then
            dput -f "$PPA" "${PACKAGE}_${DIST_VERSION}_source.changes"

            # save changelog for next time
            cp $SOURCE/debian/changelog $DIST.changelog
        else
            echo "> skipping..."
        fi
    done

    # save the revision for next time
    # FIXME: what if one dist build succeeds and another fails?
    if [ -z "$OPT_DRYRUN" ]; then
        echo "$REV" > prev.rev
    fi
    popd
done
