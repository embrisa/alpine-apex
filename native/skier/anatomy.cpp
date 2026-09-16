#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <algorithm>
#include <cmath>
#include <vector>
using namespace godot;

// Presentation-only port of the retained Anatomy.fit_pelvis and its called
// RiderBody.fit_hips/joint math. No access to simulation or scene state.
// Scalars follow GDScript double precision; Godot vectors/bases remain real_t.
class AlpineSkierAnatomy : public RefCounted {
    GDCLASS(AlpineSkierAnatomy, RefCounted)
    struct Side {
        Vector3 offset; Basis lower_inverse; double thigh, shin, minimum;
        Vector3 arm_axis, arm_upper, arm_lower, arm_upper_unit, arm_lower_unit;
        Basis elbow_zero;
        double rest_bend;
    } sides[2];
    struct TrackedBone {
        String name;
        Vector3 offset;
        std::vector<int> grip_chain;
        bool forearm = false;
        int side = 0;
    };
    std::vector<TrackedBone> tracked_bones;
    static constexpr double pi = 3.14159265358979323846;
    static double rad(double degrees) { return degrees * (pi / 180.0); }
    static Vector3 mul(Vector3 v, double scalar) { return v * real_t(scalar); }
    static Basis frame(Vector3 direction, Vector3 hinge) {
        Vector3 normal = hinge.slide(direction).normalized();
        return Basis(direction, normal, direction.cross(normal).normalized());
    }
    static double twist(Basis rotation) {
        Quaternion q = rotation.get_rotation_quaternion().normalized();
        double angle = 2.0 * std::atan2(double(Vector3(q.x,q.y,q.z).dot(Vector3(0,1,0))), double(q.w));
        double range = 2.0 * pi;
        return (angle + pi) - (range * std::floor((angle + pi) / range)) - pi;
    }
    static double soft(double value) {
        double limit = rad(14.0), magnitude = std::abs(value), start = limit * .85;
        if (magnitude > start) magnitude = start + (limit-start)*(1.0-std::exp(-(magnitude-start)/(limit-start)));
        return (value > 0.0 ? 1.0 : (value < 0.0 ? -1.0 : 0.0)) * magnitude;
    }
    static double soft_limit(double value, double low, double high) {
        double limit=value>=0.0 ? high : -low;
        double magnitude=std::abs(value), start=limit*.85;
        if (magnitude>start) magnitude=start+(limit-start)*(1.0-std::exp(-(magnitude-start)/(limit-start)));
        return (value>0.0 ? 1.0 : (value<0.0 ? -1.0 : 0.0))*magnitude;
    }
    static Vector3 rotation_vector(Quaternion q) {
        q.normalize();
        if (q.w<0.0) q=-q;
        Vector3 xyz(q.x,q.y,q.z);
        return mul(mul(xyz.normalized(),2.0),std::atan2(double(xyz.length()),std::max(0.0,double(q.w))));
    }
    static Basis from_vector(Vector3 v) {
        return v.length_squared()>.00000001 ? Basis(v.normalized(),v.length()) : Basis();
    }
    static Basis box_limit(Basis rotation, Vector3 low, Vector3 high) {
        Vector3 v=rotation_vector(rotation.get_rotation_quaternion());
        for (int i=0;i<3;++i) v[i]=real_t(soft_limit(v[i],rad(low[i]),rad(high[i])));
        return from_vector(v);
    }
    static double angle_twist(Basis rotation, Vector3 axis) {
        Quaternion q=rotation.get_rotation_quaternion().normalized();
        double angle=2.0*std::atan2(double(Vector3(q.x,q.y,q.z).dot(axis)),double(q.w));
        double range=2.0*pi;
        return (angle+pi)-(range*std::floor((angle+pi)/range))-pi;
    }
    static Basis swing_limit(Basis rotation, Vector3 axis, double swing_degrees, double twist_degrees) {
        double angle=angle_twist(rotation,axis);
        Basis swing=rotation*Basis(axis,real_t(-angle));
        Vector3 v=rotation_vector(swing.get_rotation_quaternion());
        double limited=soft_limit(v.length(),-rad(swing_degrees),rad(swing_degrees));
        return from_vector(mul(v.normalized(),limited))*Basis(axis,real_t(soft_limit(angle,-rad(twist_degrees),rad(twist_degrees))));
    }
    static double lerp_scalar(double from, double to, double weight) { return from+(to-from)*weight; }
    static double smooth(double low, double high, double value) {
        double t=std::clamp((value-low)/(high-low),0.0,1.0);
        return t*t*(3.0-2.0*t);
    }
    Basis tracked_grip(int index, Basis original, const TypedArray<Quaternion> &tracked, Vector3 action) const {
        const TrackedBone &bone=tracked_bones[index];
        double sum=double(action.x)+double(action.y)+double(action.z);
        double amount=std::clamp(sum,0.0,1.0);
        if (amount<.00001 || bone.grip_chain.empty()) return original;
        // Rebuild this arm after its parents have advanced, including again
        // for the hand after the forearm advances. Never cache a dynamic pose.
        Basis forearm, arm;
        Vector3 wrist;
        for (int ancestor : bone.grip_chain) {
            wrist+=forearm.xform(tracked_bones[ancestor].offset);
            arm=forearm;
            forearm=forearm*Basis(Quaternion(tracked[ancestor]));
        }
        const Side &side=sides[bone.side];
        double sign=bone.side==0 ? -1.0 : 1.0;
        Basis hinge=local_limit(bone.side==0 ? "RightForeArm" : "LeftForeArm",original,0.0,0.0);
        if (bone.forearm) forearm=arm*hinge;
        wrist+=forearm.xform(side.arm_lower);
        Vector3 mix=action/real_t(std::max(sum,.00001));
        Vector3 trail=Vector3(sign*(.24*mix.x+.12*mix.y+.18*mix.z),-.62,-1.0).normalized();
        Vector3 passage(sign*.38,-.05,0.0), grip=wrist, corridor=trail;
        for (int iteration=0;iteration<3;++iteration) {
            passage.y=real_t(lerp_scalar(-.05,std::min(-.05,double(grip.y)-.20),mix.z));
            corridor=(passage-grip).normalized();
            Vector3 aim_z=-corridor, aim_x=forearm.get_column(0).slide(aim_z).normalized();
            grip=wrist+Basis(aim_x,aim_z.cross(aim_x),aim_z).xform(Vector3(sign*.070,0,.018));
        }
        double near_body=1.0-smooth(.32,.48,std::abs(double(wrist.x)));
        double route=(double(mix.y)+double(mix.z)+double(mix.x)*near_body)*smooth(.08,.32,wrist.z);
        trail=trail.slerp(corridor,real_t(route)).normalized();
        Vector3 z=-trail, x=forearm.get_column(0).slide(z).normalized();
        Basis wanted=forearm.transposed()*Basis(x,z.cross(x),z);
        if (bone.forearm) wanted=hinge*Basis(side.arm_lower_unit,real_t(angle_twist(wanted,side.arm_lower_unit)));
        return original.orthonormalized().slerp(wanted.orthonormalized(),real_t(amount));
    }
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
        ClassDB::bind_method(D_METHOD("configure","rest_sides"),&AlpineSkierAnatomy::configure);
        ClassDB::bind_method(D_METHOD("fit_pelvis","hips","pelvis","ankles","boots"),&AlpineSkierAnatomy::fit_pelvis);
        ClassDB::bind_method(D_METHOD("fit_render_knee","prefix","hip","ankle","source_knee","boot","thigh","shin","weight"),&AlpineSkierAnatomy::fit_render_knee);
        ClassDB::bind_method(D_METHOD("local_limit","id","rotation","pole_carry","forearm_carry"),&AlpineSkierAnatomy::local_limit);
        ClassDB::bind_method(D_METHOD("configure_tracking","names","parents","rest","chains"),&AlpineSkierAnatomy::configure_tracking);
        ClassDB::bind_method(D_METHOD("track_pose","requested","current","velocities","action","pole_carry","forearm_carry","dt"),&AlpineSkierAnatomy::track_pose);
    }
public:
    void configure_tracking(Array names, PackedInt32Array parents, Dictionary rest, Dictionary chains) {
        ERR_FAIL_COND(names.size()!=parents.size());
        tracked_bones.clear();
        tracked_bones.resize(names.size());
        for (int i=0;i<names.size();++i) {
            TrackedBone &bone=tracked_bones[i];
            bone.name=names[i];
            bone.side=bone.name.begins_with("Right") ? 0 : 1;
            bone.forearm=bone.name.ends_with("ForeArm");
            if (parents[i]>=0 && rest.has(names[i])) {
                ERR_FAIL_COND(!rest.has(names[parents[i]]));
                bone.offset=Vector3(rest[names[i]])-Vector3(rest[names[parents[i]]]);
            }
            if (chains.has(names[i])) {
                PackedInt32Array chain=chains[names[i]];
                int previous=-1;
                for (int j=0;j<chain.size();++j) {
                    int ancestor=chain[j];
                    ERR_FAIL_COND(ancestor<0 || ancestor>=names.size() || parents[ancestor]!=previous || !rest.has(names[ancestor]));
                    bone.grip_chain.push_back(ancestor);
                    previous=ancestor;
                }
            }
        }
    }
    Vector2 track_pose(TypedArray<Quaternion> requested, TypedArray<Quaternion> current,
            TypedArray<Vector3> velocities, Vector3 action, double pole_carry, double forearm_carry, double dt) const {
        int count=int(tracked_bones.size());
        ERR_FAIL_COND_V(count==0 || requested.size()!=count || current.size()!=count || velocities.size()!=count,Vector2());
        double max_accel=0.0, max_speed=0.0;
        for (int i=0;i<count;++i) {
            Basis target=tracked_grip(i,Basis(Quaternion(requested[i])),current,action);
            Quaternion rotation=current[i];
            Quaternion limited=local_limit(tracked_bones[i].name,target,pole_carry,forearm_carry).get_rotation_quaternion();
            Vector3 error=rotation_vector(limited*rotation.inverse());
            Vector3 velocity=velocities[i];
            Vector3 accel=(mul(error,1600.0)-mul(velocity,80.0)).limit_length(160.0);
            velocity=(velocity+mul(accel,dt)).limit_length(12.0);
            velocities[i]=velocity;
            double speed=velocity.length();
            if (speed>.000001) current[i]=(Quaternion(velocity/real_t(speed),real_t(speed*dt))*rotation).normalized();
            max_accel=std::max(max_accel,double(accel.length()));
            max_speed=std::max(max_speed,speed);
        }
        return Vector2(max_accel,max_speed);
    }
    void configure(Dictionary rest_sides) {
        for (int i=0;i<2;++i) {
            Dictionary data=rest_sides[i==0 ? "Right" : "Left"];
            sides[i].offset=data["hip_offset"]; sides[i].lower_inverse=data["leg_lower_inverse"];
            sides[i].thigh=data["thigh"]; sides[i].shin=data["shin"]; sides[i].minimum=data["minimum"];
            sides[i].arm_axis=data["arm_axis"]; sides[i].arm_upper=data["arm_upper"]; sides[i].arm_lower=data["arm_lower"];
            sides[i].arm_upper_unit=data["arm_upper_unit"]; sides[i].arm_lower_unit=data["arm_lower_unit"];
            sides[i].elbow_zero=data["elbow_zero"]; sides[i].rest_bend=data["rest_bend"];
        }
    }
    Basis local_limit(String id, Basis rotation, double pole_carry, double forearm_carry) const {
        if (id=="Hips") return box_limit(rotation,Vector3(-18,-25,-32),Vector3(55,25,32));
        if (id=="Spine02" || id=="Spine01" || id=="Spine") return box_limit(rotation,Vector3(-8,-10,-8),Vector3(20,10,8));
        if (id=="neck") return box_limit(rotation,Vector3(-22,-28,-14),Vector3(22,28,14));
        if (id=="Head") return box_limit(rotation,Vector3(-30,-30,-12),Vector3(24,30,12));
        const Side &side=sides[id.begins_with("Right") ? 0 : 1];
        if (id.ends_with("Shoulder")) return box_limit(rotation,Vector3(-12,-15,-12),Vector3(12,15,12));
        if (id.ends_with("ForeArm")) {
            Vector3 direction=rotation.xform(side.arm_lower).slide(side.arm_axis).normalized();
            double angle=side.arm_upper.signed_angle_to(direction,side.arm_axis);
            angle=std::clamp(angle,rad(6.0),rad(145.0));
            Basis hinge=Basis(side.arm_axis,real_t(angle-side.rest_bend))*side.elbow_zero;
            double roll=angle_twist(hinge.transposed()*rotation,side.arm_lower_unit);
            return hinge*Basis(side.arm_lower_unit,real_t(std::clamp(roll,-rad(170)*forearm_carry,rad(170)*forearm_carry)));
        }
        if (id.ends_with("Arm")) return swing_limit(rotation,side.arm_upper_unit,125.0,55.0);
        if (id.ends_with("Hand")) {
            double carry=std::clamp(pole_carry,0.0,1.0);
            return swing_limit(rotation,side.arm_lower_unit,
                lerp_scalar(lerp_scalar(28.0,80.0,carry),80.0,forearm_carry),
                lerp_scalar(lerp_scalar(55.0,90.0,carry),30.0,forearm_carry));
        }
        return rotation;
    }
    Vector3 fit_render_knee(String prefix, Vector3 hip, Vector3 ankle, Vector3 source_knee,
            Basis boot, double thigh, double shin_length, double weight) const {
        Vector3 cuff=joint(hip,ankle,thigh,shin_length,boot.get_column(1)+mul(boot.get_column(2),.45));
        Vector3 delta=(ankle-hip).normalized();
        Vector3 hint=(cuff-hip).slide(delta).normalized();
        Vector3 source_pole=(source_knee-hip).slide(delta);
        Vector3 native_hint=source_pole.normalized();
        double pole_weight=smooth(.03,.12,source_pole.length());
        double angle=double(hint.cross(native_hint).dot(delta))*rad(10.0)*weight*pole_weight;
        double lo=0.0, hi=1.0;
        Vector3 knee=cuff;
        Basis inverse=boot.transposed();
        const Side &side=sides[prefix=="Right" ? 0 : 1];
        for (int iteration=0;iteration<10;++iteration) {
            double t=(lo+hi)*.5;
            Vector3 candidate=joint(hip,ankle,thigh,shin_length,hint.rotated(delta,real_t(angle*t)));
            Vector3 axis=inverse.xform((candidate-ankle).normalized());
            double side_angle=std::abs(std::atan2(double(axis.x),double(axis.y)));
            double flex=std::atan2(double(axis.z),double(axis.y));
            bool accepted=side_angle<=rad(10.05) && flex>=rad(-.05) && flex<=rad(24.05);
            if (accepted) {
                Vector3 lower=(ankle-candidate).normalized();
                Vector3 normal=(candidate-hip).normalized().cross(lower).normalized();
                Basis shin=frame(lower,normal)*side.lower_inverse;
                accepted=std::abs(twist(inverse*shin))<rad(18.0);
            }
            if (accepted) { lo=t; knee=candidate; } else { hi=t; }
        }
        return knee;
    }
    Vector3 fit_pelvis(Vector3 hips, Basis pelvis, TypedArray<Vector3> ankle_array, TypedArray<Basis> boot_array) const {
        ERR_FAIL_COND_V(ankle_array.size()!=2 || boot_array.size()!=2, hips);
        Vector3 ankles[2]={ankle_array[0],ankle_array[1]};
        Basis boots[2]={boot_array[0],boot_array[1]};
        Vector3 offsets[2]={pelvis.xform(sides[0].offset),pelvis.xform(sides[1].offset)};
        Basis inverse[2]={boots[0].transposed(),boots[1].transposed()};
        for (int iteration=0;iteration<12;++iteration) {
            hips=fit_hips(hips,offsets,ankles,boots,inverse);
            double largest=0.0;
            for (int i=0;i<2;++i) {
                Vector3 hip=hips+offsets[i], delta=hip-ankles[i];
                if (delta.length()<sides[i].minimum) {
                    Vector3 shift=mul(delta.normalized(),sides[i].minimum-double(delta.length()));
                    hips+=shift; hip+=shift; largest=std::max(largest,double(shift.length()));
                }
                Vector3 knee=leg_joint(hip,ankles[i],i,boots[i]);
                Vector3 cuff_axis=inverse[i].xform((knee-ankles[i]).normalized());
                double flex=std::atan2(double(cuff_axis.z),double(cuff_axis.y));
                if (flex>rad(24.0)) {
                    Vector3 allowed=cuff_axis.rotated(Vector3(1,0,0),real_t(rad(24.0)-flex));
                    Vector3 fitted=ankles[i]+mul(boots[i].xform(allowed),sides[i].shin);
                    Vector3 shift=fitted+mul((hip-fitted).normalized(),sides[i].thigh)-hip;
                    hips+=shift; hip+=shift; largest=std::max(largest,double(shift.length()));
                    knee=leg_joint(hip,ankles[i],i,boots[i]);
                }
                Vector3 lower=(ankles[i]-knee).normalized();
                Vector3 normal=(knee-hip).normalized().cross(lower).normalized();
                Basis shin=frame(lower,normal)*sides[i].lower_inverse;
                double angle=twist(inverse[i]*shin), allowed=soft(angle);
                if (std::abs(angle-allowed)<.0001) continue;
                Vector3 plane=normal.rotated(-lower,real_t(allowed-angle));
                Vector3 corrected=knee+mul((hip-knee).slide(plane).normalized(),sides[i].thigh);
                Vector3 shift=corrected-hip;
                hips+=shift; largest=std::max(largest,double(shift.length()));
            }
            if (largest<.00005) break;
        }
        return fit_hips(hips,offsets,ankles,boots,inverse);
    }
};
void register_skier_anatomy() { ClassDB::register_class<AlpineSkierAnatomy>(); }
