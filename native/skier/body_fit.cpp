#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;
// RiderBody.fit_hips equations and evaluation order; no scene or session access.
class AlpineBodyFit : public RefCounted {
    GDCLASS(AlpineBodyFit, RefCounted)
    struct Side { Vector3 offset; double thigh, shin; } sides[2];
    static Vector3 mul(Vector3 v, double scalar) { return v * real_t(scalar); }
    static Vector3 joint(Vector3 a, Vector3 b, double first, double second, Vector3 hint) {
        Vector3 delta = b-a;
        double length = std::clamp(double(delta.length()), std::abs(first-second)+.0001, first+second-.0001);
        Vector3 direction = delta.normalized();
        double along = (first*first-second*second+length*length)/(2.0*length);
        double height = std::sqrt(std::max(0.0,first*first-along*along));
        Vector3 bend = hint-mul(direction,hint.dot(direction));
        if (bend.length_squared()<.0001) bend = Vector3(1,0,0).slide(direction);
        return a+mul(direction,along)+mul(bend.normalized(),height);
    }
    Vector3 leg_joint(Vector3 hip, Vector3 ankle, int i, Basis boot) const {
        return joint(hip,ankle,sides[i].thigh,sides[i].shin,boot.get_column(1)+mul(boot.get_column(2),.45));
    }
    Vector3 fit_hips(Vector3 hips, const Vector3* offsets, const Vector3* ankles, const Basis* boots, const Basis* inverse) const {
        for (int iteration=0; iteration<16; ++iteration) {
            double largest=0.0;
            for (int i=0; i<2; ++i) {
                Vector3 hip=hips+offsets[i];
                double reach=sides[i].thigh+sides[i].shin-.004;
                double extension=double(hip.distance_to(ankles[i]))-reach;
                if (extension>0.0) {
                    Vector3 shift=mul((ankles[i]-hip).normalized(),extension);
                    hips+=shift; hip+=shift; largest=std::max(largest,extension);
                }
                Vector3 knee=leg_joint(hip,ankles[i],i,boots[i]);
                Vector3 axis=inverse[i].xform((knee-ankles[i]).normalized());
                double side_angle=std::clamp(std::atan2(double(axis.x),double(axis.y)),-.174533,.174533);
                double flex=std::clamp(std::asin(std::clamp(double(axis.z),-1.0,1.0)),0.0,.558505);
                Vector3 allowed(std::sin(side_angle)*std::cos(flex),std::cos(side_angle)*std::cos(flex),std::sin(flex));
                if (axis.distance_squared_to(allowed)<.00000001) continue;
                Vector3 cuff_knee=ankles[i]+mul(boots[i].xform(allowed),sides[i].shin);
                Vector3 corrected=cuff_knee+mul((hip-cuff_knee).normalized(),sides[i].thigh);
                Vector3 correction=corrected-hip;
                hips+=correction; largest=std::max(largest,double(correction.length()));
            }
            if (largest<.00001) break;
        }
        return hips;
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("configure","rest"),&AlpineBodyFit::configure);
        ClassDB::bind_method(D_METHOD("fit","hips","pelvis","ankles","boots"),&AlpineBodyFit::fit);
    }
public:
    void configure(Dictionary rest) {
        Vector3 hips=rest["Hips"];
        for(int i=0;i<2;++i) {
            String prefix=i==0 ? "Right" : "Left";
            Vector3 upper=rest[prefix+"UpLeg"], knee=rest[prefix+"Leg"], ankle=rest[prefix+"Foot"];
            sides[i].offset=upper-hips;
            sides[i].thigh=upper.distance_to(knee); sides[i].shin=knee.distance_to(ankle);
        }
    }
    Vector3 fit(Vector3 hips, Basis pelvis, TypedArray<Vector3> ankle_array, TypedArray<Basis> boot_array) const {
        ERR_FAIL_COND_V(ankle_array.size()!=2 || boot_array.size()!=2,hips);
        Vector3 ankles[2]={ankle_array[0],ankle_array[1]};
        Basis boots[2]={boot_array[0],boot_array[1]};
        Vector3 offsets[2]={pelvis.xform(sides[0].offset),pelvis.xform(sides[1].offset)};
        Basis inverse[2]={boots[0].transposed(),boots[1].transposed()};
        return fit_hips(hips,offsets,ankles,boots,inverse);
    }
};
void register_skier_body_fit() { ClassDB::register_class<AlpineBodyFit>(); }
