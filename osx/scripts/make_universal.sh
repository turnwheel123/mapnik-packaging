mkdir -p "${BUILD_UNIVERSAL}"

echo '*making universal libs*'
# TODO - make this list more generic
for i in {"icudata","icui18n","icuuc","protobuf","protobuf-lite","boost_regex","boost_system","boost_filesystem","boost_thread","png","jpeg","xml2","z","freetype","bz2"}
do
    echo '*making universal '$i'*'
    lipo -create -output \
        "${BUILD_UNIVERSAL}/lib${i}.a" \
        "${BUILD_ROOT}-x86_64/lib/lib${i}.a" \
        "${BUILD_ROOT}-armv7s/lib/lib${i}.a" \
        "${BUILD_ROOT}-armv7/lib/lib${i}.a" \
        "${BUILD_ROOT}-i386/lib/lib${i}.a"
done

# mapnik
echo '*making universal mapnik*'
lipo -create -output \
    "${BUILD_UNIVERSAL}/libmapnik.a" \
    "${BUILD_ROOT}-x86_64-mapnik/${MAPNIK_INSTALL}/lib/libmapnik.a" \
    "${BUILD_ROOT}-armv7s-mapnik/${MAPNIK_INSTALL}/lib/libmapnik.a" \
    "${BUILD_ROOT}-armv7-mapnik/${MAPNIK_INSTALL}/lib/libmapnik.a" \
    "${BUILD_ROOT}-i386-mapnik/${MAPNIK_INSTALL}/lib/libmapnik.a"

# strip -o libmapnik.a -S out/build-universal/libmapnik.a
# http://stackoverflow.com/questions/6732979/hiding-the-symbols-of-a-static-library-in-a-dynamic-library-in-mac-os-x
# http://stackoverflow.com/questions/2222162/how-to-apply-gcc-fvisibility-option-to-symbols-in-static-libraries/14863432#14863432

#for i in {"shape","csv","geojson","sqlite"}
#do
#    echo '*making universal '$i'*'
#    lipo -create -output \
#        "${BUILD_UNIVERSAL}/lib/mapnik/input/${i}.input" \
#        "${BUILD_ROOT}-x86_64-mapnik/${MAPNIK_INSTALL}/lib/mapnik/input/${i}.input"
#done
